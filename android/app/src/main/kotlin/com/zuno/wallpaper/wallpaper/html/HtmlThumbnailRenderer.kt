package com.zuno.wallpaper.wallpaper.html

import android.content.Context
import android.graphics.Bitmap
import android.graphics.Canvas
import android.os.Handler
import android.os.Looper
import android.util.Log
import android.webkit.WebView
import java.io.File
import java.io.FileOutputStream

/**
 * HTML 壁纸的离屏截图缩略图渲染器。
 *
 * 与壁纸引擎共用 [SandboxedWebViewFactory]（同一套沙箱：appassets.local 假源、
 * 禁网、禁 file://、仅 setConfig 桥），在离屏 WebView 上加载页面、等待就绪与
 * 首帧稳定后，走与壁纸渲染完全相同的 `view.draw(canvas)` 软件路径截图。
 * 因此缩略图 = 壁纸真实渲染效果（不是猜测的占位图）。
 *
 * 时序：onPageFinished → SETTLE_MS（等首帧动画/字体/图片稳定）→ 截图 → destroy。
 * 超时保护：页面卡住/加载失败时在 TIMEOUT_MS 放弃（Dart 侧显示占位图标）。
 *
 * 必须在主线程调用（WebView 的创建/绘制约束）；整个流程异步，不阻塞 UI。
 */
object HtmlThumbnailRenderer {

    private const val TAG = "ZunoThumb"
    private const val WIDTH = 480
    private const val HEIGHT = 800
    private const val SETTLE_MS = 1200L
    private const val TIMEOUT_MS = 8000L
    private const val JPEG_QUALITY = 82

    fun render(
        context: Context,
        packageRoot: File,
        entryRelativePath: String,
        outPath: String,
        onDone: (String?) -> Unit,
    ) {
        val handler = Handler(Looper.getMainLooper())
        var webView: WebView? = null
        var finished = false

        fun cleanup(success: Boolean) {
            if (finished) return
            finished = true
            handler.removeCallbacksAndMessages(null)
            webView?.let { view ->
                runCatching {
                    view.onPause()
                    view.removeAllViews()
                    view.destroy()
                }
            }
            webView = null
            onDone(if (success) outPath else null)
        }

        try {
            webView = SandboxedWebViewFactory.create(
                context = context,
                packageRoot = packageRoot,
                entryRelativePath = entryRelativePath,
                configJson = "{}",
                onSetConfig = { _, _ -> /* 截图流程不落任何配置 */ },
                onPageReady = { _ ->
                    handler.postDelayed({
                        if (finished) return@postDelayed
                        val view = webView
                        if (view == null) {
                            cleanup(false)
                            return@postDelayed
                        }
                        try {
                            val bitmap = Bitmap.createBitmap(WIDTH, HEIGHT, Bitmap.Config.ARGB_8888)
                            val canvas = Canvas(bitmap)
                            // view.draw 对未挂窗的 WebView 走软件快照路径（引擎 v2 的
                            // VirtualDisplay 用于实时渲染，截图用不到硬件层）。
                            canvas.drawColor(android.graphics.Color.BLACK)
                            view.draw(canvas)
                            val out = File(outPath)
                            out.parentFile?.mkdirs()
                            FileOutputStream(out).use { fos ->
                                bitmap.compress(Bitmap.CompressFormat.JPEG, JPEG_QUALITY, fos)
                            }
                            bitmap.recycle()
                            cleanup(true)
                        } catch (t: Throwable) {
                            Log.w(TAG, "html thumbnail capture failed", t)
                            cleanup(false)
                        }
                    }, SETTLE_MS)
                },
            ).also { view ->
                view.layout(0, 0, WIDTH, HEIGHT)
            }
            // 超时保护：放弃截图（Dart 侧回退占位图标），绝不让调用方悬空等待。
            handler.postDelayed({ cleanup(false) }, TIMEOUT_MS)
        } catch (t: Throwable) {
            Log.w(TAG, "html thumbnail renderer failed", t)
            cleanup(false)
        }
    }
}
