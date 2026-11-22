package com.zuno.wallpaper.wallpaper.engine

import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.media.MediaMetadataRetriever
import android.net.Uri
import android.util.Log
import android.view.SurfaceHolder
import androidx.media3.common.MediaItem
import androidx.media3.common.PlaybackException
import androidx.media3.common.Player
import androidx.media3.common.util.UnstableApi
import androidx.media3.exoplayer.DefaultRenderersFactory
import androidx.media3.exoplayer.ExoPlayer
import androidx.media3.exoplayer.mediacodec.MediaCodecSelector
import androidx.media3.exoplayer.mediacodec.MediaCodecUtil
import com.zuno.wallpaper.wallpaper.ActiveWallpaper
import com.zuno.wallpaper.wallpaper.ActiveWallpaperStore
import com.zuno.wallpaper.wallpaper.PerformanceTier
import org.json.JSONObject
import java.io.File

/**
 * 视频壁纸：ExoPlayer 直连 SurfaceHolder 的 Surface。
 *
 * 为什么从 MediaPlayer 换成 ExoPlayer：
 * - MediaPlayer 无法指定解码器，4K/AV1 等格式解码失败时只能降级静态首帧；
 * - ExoPlayer 的 MediaCodecSelector 可以显式挑选软/硬解码器，配合设置页的
 *   “自动 / 硬件 / 软件”三档，让用户在硬解失败后仍有机会播放；
 * - 循环、倍速、Surface 生命周期都由播放器统一管理，避免 MediaPlayer 在
 *   surface 销毁/重建时的状态机陷阱。
 *
 * 解码方式：
 * - auto：优先硬件解码器；设备完全没有硬解时才退回软解（不会在运行中静默切换）；
 * - hardware：只允许硬件解码器；
 * - software：只允许软件解码器（性能消耗高，可能发热/掉帧）。
 *
 * 任一模式失败都会把错误写入 SharedPreferences，Flutter 端下次回到前台时
 * 弹出提示，让用户决定是否切换到软件解码——这里不自动切换，避免用户
 * 在不知情的情况下承担数倍的耗电。
 */
@Suppress("UnstableApiUsage")
class VideoWallpaperEngine(
    private val context: Context,
    private var wallpaper: ActiveWallpaper,
) : WallpaperEngineDelegate {

    companion object {
        private const val TAG = "ZunoVideo"
    }

    private var player: ExoPlayer? = null
    private var decodeMode = ActiveWallpaperStore.videoDecodeMode(context)
    private var prepared = false
    private var surfaceHolder: SurfaceHolder? = null
    private var surfaceReady = false
    private var visible = false
    private var powerSave = false

    private val tier: PerformanceTier
        get() = PerformanceTier.parse(ActiveWallpaperStore.performanceTier(context))

    private val playerListener = object : Player.Listener {
        override fun onPlaybackStateChanged(playbackState: Int) {
            if (playbackState == Player.STATE_READY) {
                prepared = true
                applyConfig()
                maybeStart()
            }
        }

        override fun onRenderedFirstFrame() {
            // 真正出画面才清除失败记录：prepare 成功但解码器拒绝格式的情况也存在。
            ActiveWallpaperStore.clearVideoDecodeFailure(context)
        }

        override fun onPlayerError(error: PlaybackException) {
            Log.e(TAG, "player error ${error.errorCodeName}, falling back to static frame", error)
            val message = buildString {
                append(error.errorCodeName)
                error.message?.takeIf { it.isNotBlank() }?.let { append(": ").append(it) }
            }
            ActiveWallpaperStore.recordVideoDecodeFailure(context, wallpaper.id, message)
            releasePlayer()
            showStaticFirstFrame()
        }
    }

    // ---------- 生命周期 ----------

    override fun onSurfaceCreated(holder: SurfaceHolder) {
        surfaceHolder = holder
        surfaceReady = holder.surface?.isValid == true
        ensurePlayer()
        player?.setVideoSurfaceHolder(holder)
        applyConfig()
        maybeStart()
    }

    override fun onSurfaceChanged(holder: SurfaceHolder, format: Int, width: Int, height: Int) {
        // ExoPlayer 会按 Surface 尺寸自动缩放（letterbox），无需干预。
        surfaceHolder = holder
    }

    override fun onSurfaceDestroyed(holder: SurfaceHolder) {
        // 回调返回后 Surface 失效：必须先解除绑定，否则解码器写入已销毁的
        // 缓冲区会导致崩溃。暂停同时避免无输出 Sink 空转耗电。
        player?.pause()
        player?.clearVideoSurface()
        surfaceReady = false
        surfaceHolder = null
    }

    override fun onVisibilityChanged(visible: Boolean) {
        this.visible = visible
        if (!visible) {
            pause()
        } else {
            maybeStart()
        }
    }

    override fun onPowerSaveChanged(powerSave: Boolean) {
        this.powerSave = powerSave
        if (powerSave) {
            pause()
            runCatching { player?.seekTo(0) }
        } else {
            maybeStart()
        }
    }

    override fun onTouchEvent(event: android.view.MotionEvent) = Unit

    override fun onConfigChanged(configJson: String) {
        wallpaper = wallpaper.copy(configJson = configJson)
        val latestMode = ActiveWallpaperStore.videoDecodeMode(context)
        if (latestMode != decodeMode) {
            // 解码方式切换必须重建 RenderersFactory；同一 Surface 重新绑定即可。
            decodeMode = latestMode
            val holder = surfaceHolder
            releasePlayer()
            ensurePlayer()
            if (holder != null) player?.setVideoSurfaceHolder(holder)
        }
        applyConfig()
        maybeStart()
    }

    override fun onDestroy() {
        releasePlayer()
        cachedColors = null
    }

    // ---------- 主题色（Material You 启动器/锁屏着色） ----------

    private var cachedColors: android.app.WallpaperColors? = null

    /** 从包缩略图提取 WallpaperColors（结果缓存；缩略图即导入期的首帧截图）。 */
    private fun computeColors(): android.app.WallpaperColors? {
        if (android.os.Build.VERSION.SDK_INT < 27) return null
        cachedColors?.let { return it }
        // 用缩略图取色而非 onComputeColors 里现解视频首帧：取色回调跑在主线程
        // （无 android:process，与 Flutter UI 同一线程），getFrameAtTime 对
        // 4K 视频可达数百 ms，会 ANR；缩略图是导入期生成的小图，解码毫秒级，
        // 观感等价（首帧截图或作者图）。
        val bmp = loadThumbnailBitmap() ?: return null
        return try {
            val colors = android.app.WallpaperColors.fromBitmap(bmp)
            cachedColors = colors
            colors
        } catch (t: Throwable) {
            Log.w(TAG, "video colors compute failed", t)
            null
        } finally {
            bmp.recycle()
        }
    }

    /** 包缩略图：作者提供的 thumbnail.png 优先，否则导入时生成的 thumbnail.jpg。 */
    private fun loadThumbnailBitmap(): Bitmap? =
        sequenceOf("thumbnail.png", "thumbnail.jpg")
            .map { File(wallpaper.dir, it) }
            .firstOrNull { it.isFile }
            ?.let { runCatching { BitmapFactory.decodeFile(it.absolutePath) }.getOrNull() }

    override fun onComputeColors(): android.app.WallpaperColors? = computeColors()

    // ---------- 内部 ----------

    /** 媒体源缺失或解码失败时的静态画面：视频首帧 → 包缩略图 → 保持黑屏。 */
    private fun showStaticFirstFrame() {
        val surface = surfaceHolder?.surface ?: return
        if (!surface.isValid) return
        val frame = try {
            val retriever = MediaMetadataRetriever()
            try {
                retriever.setDataSource(File(wallpaper.dir, wallpaper.entry).absolutePath)
                retriever.getFrameAtTime(0, MediaMetadataRetriever.OPTION_CLOSEST_SYNC)
            } finally {
                runCatching { retriever.release() }
            }
        } catch (t: Throwable) {
            null
        } ?: loadThumbnailBitmap() ?: return

        try {
            val canvas = surface.lockCanvas(null) ?: return
            try {
                canvas.drawColor(android.graphics.Color.BLACK)
                // center-crop：与播放器填满 Surface 的呈现方式一致。
                val s = maxOf(
                    canvas.width.toFloat() / frame.width,
                    canvas.height.toFloat() / frame.height,
                )
                val dw = (frame.width * s).toInt().coerceAtLeast(1)
                val dh = (frame.height * s).toInt().coerceAtLeast(1)
                val scaled = if (dw != frame.width || dh != frame.height) {
                    Bitmap.createScaledBitmap(frame, dw, dh, true)
                } else {
                    frame
                }
                canvas.drawBitmap(
                    scaled,
                    ((canvas.width - dw) / 2).toFloat(),
                    ((canvas.height - dh) / 2).toFloat(),
                    null,
                )
                if (scaled !== frame) scaled.recycle()
            } finally {
                surface.unlockCanvasAndPost(canvas)
                frame.recycle()
            }
        } catch (t: Throwable) {
            Log.w(TAG, "static first frame fallback failed", t)
        }
    }

    private fun ensurePlayer() {
        if (player != null) return
        val file = File(wallpaper.dir, wallpaper.entry)
        if (!file.isFile) {
            ActiveWallpaperStore.recordVideoDecodeFailure(
                context,
                wallpaper.id,
                "视频文件不存在",
            )
            // 文件缺失无法起播放器，但包缩略图仍可画到 Surface 上——
            // 否则用户看到的是纯黑屏且没有任何恢复信号。
            showStaticFirstFrame()
            return
        }
        decodeMode = ActiveWallpaperStore.videoDecodeMode(context)
        val renderersFactory = DefaultRenderersFactory(context)
            // 不使用 ExoPlayer 的静默回退：运行中失败必须让用户决定是否软解。
            .setEnableDecoderFallback(false)
            .setMediaCodecSelector(
                MediaCodecSelector { mimeType, secure, tunneling ->
                    val all = runCatching {
                        MediaCodecUtil.getDecoderInfos(mimeType, secure, tunneling)
                    }.getOrElse {
                        Log.w(TAG, "decoder query failed for $mimeType", it)
                        emptyList()
                    }
                    val hardware = all.filter { !it.softwareOnly }
                    val software = all.filter { it.softwareOnly }
                    when (decodeMode) {
                        "software" -> software
                        "hardware" -> hardware
                        // auto：有硬解就只用硬解（失败后提示用户），完全没有才用软解。
                        else -> hardware.ifEmpty { software }
                    }
                },
            )

        try {
            val exo = ExoPlayer.Builder(context, renderersFactory).build()
            // 立即登记到字段：后续 addListener/prepare 抛错时 catch 里才能经
            // releasePlayer 释放；否则半初始化的播放器（持有引擎监听器引用）
            // 会泄漏到引擎销毁，反复重建 Surface 时累积。
            player = exo
            exo.repeatMode = Player.REPEAT_MODE_ONE
            exo.addListener(playerListener)
            exo.setMediaItem(MediaItem.fromUri(Uri.fromFile(file)))
            surfaceHolder?.let { exo.setVideoSurfaceHolder(it) }
            applyConfig(exo)
            exo.prepare()
        } catch (t: Throwable) {
            Log.e(TAG, "prepare failed for ${wallpaper.entry}", t)
            ActiveWallpaperStore.recordVideoDecodeFailure(
                context,
                wallpaper.id,
                "${t.javaClass.simpleName}: ${t.message}",
            )
            releasePlayer()
            showStaticFirstFrame()
        }
    }

    private fun applyConfig(target: ExoPlayer? = player) {
        val exo = target ?: return
        val json = runCatching { JSONObject(wallpaper.configJson) }.getOrNull()
        // 音量必须在每次配置变化时重新应用（用户经 ConfigBus 热切换后立即生效）。
        val volume = runCatching {
            (json?.optDouble("volume", 0.0) ?: 0.0).toFloat().coerceIn(0f, 1f)
        }.getOrDefault(0f)
        exo.volume = volume
        // 每次都设置倍速：之前 MediaPlayer 只在 speed != 1 时设置，用户从
        // 1.5 调回 1.0 会一直保持 1.5，是实际存在的 bug。
        val speed = runCatching {
            (json?.optDouble("playback_speed", 1.0) ?: 1.0)
                .toFloat()
                .coerceIn(0.25f, 4f)
        }.getOrDefault(1f)
        runCatching { exo.setPlaybackSpeed(speed) }
    }

    private fun maybeStart() {
        val exo = player ?: return
        if (!surfaceReady || !visible) return
        if (powerSave || tier == PerformanceTier.LOW) {
            // 性能档位 LOW / 省电：停在首帧，停止解码。
            if (prepared && exo.currentPosition > 0) runCatching { exo.seekTo(0) }
            exo.pause()
            return
        }
        // playWhenReady 在 prepare 完成前也可以设置，ExoPlayer 会在就绪后自动播放。
        exo.playWhenReady = true
    }

    private fun pause() {
        runCatching { player?.pause() }
    }

    private fun releasePlayer() {
        val exo = player
        player = null
        prepared = false
        if (exo != null) {
            runCatching {
                exo.removeListener(playerListener)
                exo.pause()
                exo.clearVideoSurface()
                exo.release()
            }
        }
    }
}
