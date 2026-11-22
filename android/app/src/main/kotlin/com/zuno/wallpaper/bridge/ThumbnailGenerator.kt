package com.zuno.wallpaper.bridge

import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.media.MediaMetadataRetriever
import android.util.Log
import java.io.File
import java.io.FileOutputStream

/**
 * 导入时自动生成壁纸库缩略图。
 *
 * 只处理两类可“便宜”出图的类型：
 * - video：MediaMetadataRetriever 取首帧（硬解管线，毫秒级）；
 * - depth：颜色图（entry 指向的 jpg/png）直接缩放。
 * html/timed 不生成（需要真实渲染页面，代价不值；这类包应自带 thumbnail.png，
 * 没有则 UI 显示占位图标）。
 *
 * 包作者提供了 thumbnail.png 时不会调用本类——尊重作者意图优先。
 */
object ThumbnailGenerator {

    private const val TAG = "ZunoThumb"
    private const val MAX_DIM = 480 // 规格建议 480×800、<200KB
    private const val JPEG_QUALITY = 82

    /**
     * 生成缩略图并写盘。任何失败返回 null（调用方保留占位图标，不阻塞导入流程）。
     *
     * @param packageDir 包根目录；entry 相对路径；outPath 输出 JPEG 的绝对路径。
     */
    fun ensure(packageDir: String, type: String, entry: String, outPath: String): String? {
        return try {
            val source = when (type) {
                "video" -> videoFirstFrame(File(packageDir, entry).absolutePath)
                "depth" -> decodeScaled(File(packageDir, entry).absolutePath)
                else -> null
            } ?: return null
            writeScaled(source, outPath)
        } catch (t: Throwable) {
            Log.w(TAG, "thumbnail generation failed for $packageDir/$entry", t)
            null
        }
    }

    private fun videoFirstFrame(path: String): Bitmap? {
        val retriever = MediaMetadataRetriever()
        return try {
            retriever.setDataSource(path)
            // OPTION_CLOSEST_SYNC：取最近关键帧，比 CLOSEST 快一个量级，缩略图够用。
            retriever.getFrameAtTime(0, MediaMetadataRetriever.OPTION_CLOSEST_SYNC)
        } finally {
            runCatching { retriever.release() }
        }
    }

    /**
     * 探测视频轨道编码（如 video/avc、video/hevc、video/av01）。
     *
     * 为什么存在：详情页预览与壁纸引擎都走 ExoPlayer，但壁纸默认只允许
     * 硬件解码（软解需用户确认），解码器仍取决于设备硬件/镜像——真机验证
     * 发现 AV1 视频“预览能放、壁纸黑屏”。导入期探测并在规格支持列表
     * （H.264/H.265）之外时给出提醒，比运行期黑屏友好得多。
     */
    fun probeVideoMime(path: String): String? {
        val extractor = android.media.MediaExtractor()
        return try {
            extractor.setDataSource(path)
            (0 until extractor.trackCount)
                .map { extractor.getTrackFormat(it) }
                .firstOrNull {
                    val mime = it.getString(android.media.MediaFormat.KEY_MIME)
                    mime != null && mime.startsWith("video/")
                }
                ?.getString(android.media.MediaFormat.KEY_MIME)
        } catch (t: Throwable) {
            Log.w(TAG, "video mime probe failed", t)
            null
        } finally {
            runCatching { extractor.release() }
        }
    }

    /**
     * 探测本机解码器是否支持该视频（profile/level/分辨率/帧率组合）。
     *
     * 为什么存在：仅看 MIME 不够 —— 4K60 的 H.264 High 5.2（avc1.640034）在
     * ExoPlayer 上会报 format_supported=NO_EXCEEDS_CAPABILITIES
     * （超出解码器能力上限），预览黑屏、壁纸只能降级静态首帧。导入期用
     * MediaCodecList 的 isFormatSupported 精确判定，提前告知用户。
     */
    fun probeVideoSupported(path: String): Boolean {
        val extractor = android.media.MediaExtractor()
        return try {
            extractor.setDataSource(path)
            val format = (0 until extractor.trackCount)
                .map { extractor.getTrackFormat(it) }
                .firstOrNull {
                    val mime = it.getString(android.media.MediaFormat.KEY_MIME)
                    mime != null && mime.startsWith("video/")
                } ?: return false
            val list = android.media.MediaCodecList(android.media.MediaCodecList.REGULAR_CODECS)
            val decoderName = list.findDecoderForFormat(format) ?: return false
            val mime = format.getString(android.media.MediaFormat.KEY_MIME)
            val caps = list.codecInfos
                .firstOrNull { it.name == decoderName }
                ?.getCapabilitiesForType(mime) ?: return false
            caps.isFormatSupported(format)
        } catch (t: Throwable) {
            Log.w(TAG, "video capability probe failed", t)
            false
        } finally {
            runCatching { extractor.release() }
        }
    }

    /**
     * 图片解码：先用 inJustDecodeBounds 读尺寸，按目标尺寸计算 inSampleSize
     * 再真正解码——超深深度图（如 4K 原图）不降采样会一次性吃掉 30MB+ 堆内存。
     */
    private fun decodeScaled(path: String): Bitmap? {
        val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
        BitmapFactory.decodeFile(path, bounds)
        if (bounds.outWidth <= 0) return null
        var sample = 1
        while (bounds.outWidth / sample > MAX_DIM * 2 || bounds.outHeight / sample > MAX_DIM * 2) {
            sample *= 2
        }
        val opts = BitmapFactory.Options().apply { inSampleSize = sample }
        return BitmapFactory.decodeFile(path, opts)
    }

    private fun writeScaled(source: Bitmap, outPath: String): String? {
        // 等比缩到最长边 MAX_DIM 以内（不放大）。
        val scale = minOf(
            MAX_DIM.toFloat() / source.width,
            MAX_DIM.toFloat() / source.height,
            1f,
        )
        val scaled = if (scale < 1f) {
            Bitmap.createScaledBitmap(
                source,
                (source.width * scale).toInt().coerceAtLeast(1),
                (source.height * scale).toInt().coerceAtLeast(1),
                true,
            )
        } else {
            source
        }
        val out = File(outPath)
        out.parentFile?.mkdirs()
        // compress 返回 false（编码器错误/磁盘满）时文件已创建但内容为空或
        // 截断——返回 null 让调用方走“无缩略图”占位路径，而不是留下一个
        // 永久坏图。
        val ok = FileOutputStream(out).use { fos ->
            scaled.compress(Bitmap.CompressFormat.JPEG, JPEG_QUALITY, fos)
        }
        if (scaled !== source) scaled.recycle()
        source.recycle()
        if (!ok) {
            out.delete()
            return null
        }
        return out.absolutePath
    }
}
