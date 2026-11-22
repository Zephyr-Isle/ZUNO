package com.zuno.wallpaper.wallpaper.engine

import android.app.Presentation
import android.content.Context
import android.graphics.Color
import android.graphics.drawable.ColorDrawable
import android.hardware.display.DisplayManager
import android.os.Bundle
import android.util.Log
import android.view.Display
import android.view.MotionEvent
import android.view.SurfaceHolder
import android.webkit.WebView
import com.zuno.wallpaper.wallpaper.ActiveWallpaper
import com.zuno.wallpaper.wallpaper.ActiveWallpaperStore
import com.zuno.wallpaper.wallpaper.ConfigBus
import com.zuno.wallpaper.wallpaper.PerformanceTier
import com.zuno.wallpaper.wallpaper.html.SandboxedWebViewFactory
import java.io.File

/**
 * HTML 交互壁纸：沙箱 WebView → VirtualDisplay + Presentation → 壁纸 Surface。
 *
 * 平台现实（重要）：WallpaperService.Engine 的窗口由系统进程创建与管理，
 * 引擎只能拿到一个 Surface，**无法在壁纸窗口内嵌入任何 View 层级**
 * （Engine API 中不存在 onCreateView；View 层级嵌入属于 DreamService）。
 *
 * 渲染架构（v2，支持 WebGL）：
 *
 *   沙箱 WebView（挂进 Presentation，拥有真实窗口 → 硬件加速）
 *     → VirtualDisplay（createVirtualDisplay 的 Surface = 壁纸 Surface）
 *     → 系统合成器把虚拟屏内容作为壁纸显示。零拷贝。
 *
 * 为什么不能用旧方案（离屏 WebView + view.draw 软件画布）：
 * 软件渲染路径下 WebGL 走 SwiftShader，全屏 shader 壁纸必然超过
 * Chromium 的 tile memory 限制（实测报 "tile memory limits exceeded,
 * some content may not draw" → 黑屏），而硬件加速窗口跑 WebGL 没有任何问题。
 *
 * 性能与功耗：
 * - 帧率由页面自己的 requestAnimationFrame 驱动（虚拟屏 vsync），
 *   引擎不再手动节流；性能档位 LOW / 省电模式 = 冻结 CSS 动画 + 暂停
 *   WebView（JS 定时器与 rAF 一并暂停）；
 * - 触摸：Engine.onTouchEvent 收到壁纸 Surface 的 MotionEvent 后直接
 *   dispatchTouchEvent 给虚拟屏里的 WebView（方法调用不依赖窗口输入路由，
 *   Chromium 自动把 touch 序列映射为页面的 pointer/mouse 事件）。
 */
class HtmlWallpaperEngine(
    private val context: Context,
    private val wallpaper: ActiveWallpaper,
) : WallpaperEngineDelegate {

    companion object {
        private const val TAG = "ZunoHtml"
        private const val FREEZE_JS =
            "(function(){var s=document.getElementById('zuno-powersave');" +
                "if(!s){s=document.createElement('style');s.id='zuno-powersave';" +
                "s.textContent='*{animation-play-state:paused !important}';" +
                "document.head.appendChild(s);}})();"
        private const val UNFREEZE_JS =
            "(function(){var s=document.getElementById('zuno-powersave');" +
                "if(s){s.parentNode.removeChild(s);}})();"
    }

    private var webView: WebView? = null
    private var presentation: HtmlPresentation? = null
    private var virtualDisplay: Display? = null
    private var virtualDisplayObj: android.hardware.display.VirtualDisplay? = null
    private var holder: SurfaceHolder? = null
    private var viewWidth = 0
    private var viewHeight = 0
    private var visible = false
    private var powerSave = false
    private var pageReady = false

    /** JS 桥回调从 JavaBridge 线程切回主线程用（config 串行写）。 */
    private val mainHandler = android.os.Handler(android.os.Looper.getMainLooper())

    /** WebView 当前是否处于 onPause（JS 定时器暂停）——幂等切换的判定依据。 */
    private var jsPaused = false
    private var frozen = false

    /** 已推送给页面 rAF 门的间隔值（-1 = 未知，强制重推）。 */
    private var pushedFrameInterval = -1L

    // 性能档位：缓存字段 + 事件时刷新（applyWebViewLifecycle 与帧间隔无关）。
    private var tier = PerformanceTier.MEDIUM

    private fun refreshTier() {
        tier = PerformanceTier.parse(ActiveWallpaperStore.performanceTier(context))
    }

    // ---------- 生命周期（主线程；Engine 回调本身就在主线程） ----------

    override fun onSurfaceCreated(holder: SurfaceHolder) {
        this.holder = holder
        viewWidth = holder.surfaceFrame.width()
        viewHeight = holder.surfaceFrame.height()
        ensurePresentation()
    }

    override fun onSurfaceChanged(holder: SurfaceHolder, format: Int, width: Int, height: Int) {
        if (width != viewWidth || height != viewHeight) {
            viewWidth = width
            viewHeight = height
            // 壁纸 Surface 尺寸变化（转屏/折叠等）：虚拟屏与内容需要按新尺寸重建。
            // 顺序关键：teardownPresentation 会把 holder 一并清空（那是给
            // onSurfaceDestroyed 用的语义），必须先 teardown 再挂新 holder，
            // 否则下面的 ensurePresentation 撞到 null holder 直接返回，
            // HTML 壁纸在 resize 后永久黑屏（只能等系统重建 Surface）。
            teardownPresentation()
            this.holder = holder
            ensurePresentation()
        } else {
            this.holder = holder
        }
    }

    override fun onSurfaceDestroyed(holder: SurfaceHolder) {
        // Surface 失效：释放虚拟屏（其中的 Presentation 一并移除）。
        teardownPresentation()
    }

    override fun onVisibilityChanged(visible: Boolean) {
        this.visible = visible
        if (visible) {
            ensurePresentation()
        }
        applyWebViewLifecycle()
    }

    override fun onPowerSaveChanged(powerSave: Boolean) {
        this.powerSave = powerSave
        applyWebViewLifecycle()
    }

    override fun onTouchEvent(event: MotionEvent) {
        // 触摸交互：把壁纸 Surface 收到的 MotionEvent 直接 dispatch 给虚拟屏里的
        // WebView。View.dispatchTouchEvent 是普通方法调用，不依赖窗口输入路由——
        // Chromium 会把 touch 序列映射为页面监听的 pointer/mouse 事件。
        // 坐标系 1:1：壁纸 Surface 尺寸 == 虚拟屏 WebView 尺寸。
        webView?.dispatchTouchEvent(event)
    }

    override fun onSurfaceRedrawNeeded(holder: SurfaceHolder) {
        // Presentation 由虚拟屏 vsync 持续驱动渲染，无需手动重绘。
    }

    override fun onConfigChanged(configJson: String) {
        // 页面已经通过 setConfig 桥触发修改；这里把最新配置重新注入全局变量，
        // 供未监听桥事件的页面代码在下一帧读取。
        webView?.evaluateJavascript("window.__ZUNO_CONFIG__ = $configJson;", null)
        // 性能档位可能随本事件变化（setPerformanceTier 走同一事件）：
        // LOW 档位要求冻结 CSS 动画 + 暂停 JS 定时器，必须立即对齐。
        applyWebViewLifecycle()
    }

    override fun onDestroy() {
        val view = webView
        webView = null
        teardownPresentation()
        cachedColors = null
        if (view != null) {
            runCatching {
                view.onPause()
                view.removeAllViews()
                view.destroy() // WebView.destroy 必须在主线程调用——Engine 回调即主线程
            }
        }
    }

    // ---------- 主题色（Material You 启动器/锁屏着色） ----------

    private var cachedColors: android.app.WallpaperColors? = null

    /**
     * 从导入时生成的页面截图缩略图提取 WallpaperColors。
     * 优先级：包作者提供的 thumbnail.png > 自动生成的 thumbnail.jpg；都没有 → null。
     */
    private fun computeColors(): android.app.WallpaperColors? {
        if (android.os.Build.VERSION.SDK_INT < 27) return null
        cachedColors?.let { return it }
        val thumb = sequenceOf("thumbnail.png", "thumbnail.jpg")
            .map { File(wallpaper.dir, it) }
            .firstOrNull { it.isFile } ?: return null
        return try {
            val bmp = android.graphics.BitmapFactory.decodeFile(thumb.absolutePath) ?: return null
            val colors = android.app.WallpaperColors.fromBitmap(bmp)
            bmp.recycle()
            cachedColors = colors
            colors
        } catch (t: Throwable) {
            Log.w(TAG, "html colors compute failed", t)
            null
        }
    }

    override fun onComputeColors(): android.app.WallpaperColors? = computeColors()

    // ---------- 内部 ----------

    private fun ensurePresentation() {
        if (presentation != null) return
        if (viewWidth <= 0 || viewHeight <= 0) return
        val h = holder ?: return
        val surface = h.surface ?: return
        if (!surface.isValid) return

        ensureWebView()
        val view = webView ?: return

        val dm = context.getSystemService(Context.DISPLAY_SERVICE) as DisplayManager
        val density = context.resources.displayMetrics.densityDpi
        val flags = DisplayManager.VIRTUAL_DISPLAY_FLAG_PRESENTATION or
            DisplayManager.VIRTUAL_DISPLAY_FLAG_OWN_CONTENT_ONLY
        virtualDisplayObj = dm.createVirtualDisplay(
            "zuno-html", viewWidth, viewHeight, density, surface, flags,
        )
        val display: Display = virtualDisplayObj?.display ?: run {
            Log.e(TAG, "createVirtualDisplay failed, html wallpaper stays black")
            return
        }
        presentation = HtmlPresentation(context, display, view).also { p ->
            // show() 在窗口 token/虚拟屏失效竞态下可能抛异常（转屏、快速锁屏
            // 时的 teardown 抢在重建前面）。失败按 createVirtualDisplay 失败
            // 处理：清空状态等下次事件重建，绝不让异常逃出 Engine 回调。
            runCatching { p.show() }.onFailure { t ->
                Log.e(TAG, "HtmlPresentation.show failed", t)
                presentation = null
                virtualDisplayObj?.release()
                virtualDisplayObj = null
            }
        }
    }

    private fun teardownPresentation() {
        presentation?.dismiss()
        presentation = null
        virtualDisplayObj?.release()
        virtualDisplayObj = null
        virtualDisplay = null
        holder = null
    }

    private fun ensureWebView() {
        if (webView != null) return
        if (viewWidth <= 0 || viewHeight <= 0) return
        try {
            // 配置以 store 为准：引擎重建（Surface 丢失等）发生在任意时刻，
            // 构造时的 configJson 字段可能已落后于用户在桥里写回的最新值。
            val latestConfig = ActiveWallpaperStore.load(context)?.configJson
                ?: wallpaper.configJson
            webView = SandboxedWebViewFactory.create(
                context = context,
                packageRoot = File(wallpaper.dir),
                entryRelativePath = wallpaper.entry,
                configJson = latestConfig,
                onSetConfig = { key, value ->
                    // JS 桥回调运行在 WebView 的 JavaBridge 线程，这里有两个坑：
                    // 1) JSONObject 解析存储的 configJson 可能因历史损坏数据抛
                    //    未捕获异常——任何线程的未捕获异常都会杀死整个壁纸进程
                    //    （桌面直接黑屏直到系统重启服务）；
                    // 2) 与主线程的 updateConfig/save 构成 read-modify-write
                    //    竞态，两次快速 setConfig 会互相覆盖丢更新。
                    // 一并解决：整体投递到主线程串行执行；解析失败仅记日志，
                    // 不让异常逃出桥线程。
                    mainHandler.post {
                        try {
                            val current =
                                ActiveWallpaperStore.load(context) ?: return@post
                            val json = org.json.JSONObject(
                                current.configJson.ifBlank { "{}" },
                            ).put(key, value)
                            ActiveWallpaperStore.updateConfig(context, json.toString())
                            ConfigBus.emit(ConfigBus.Event.CONFIG_CHANGED)
                        } catch (t: Throwable) {
                            Log.e(TAG, "setConfig: 写回壁纸参数失败", t)
                        }
                    }
                },
                onPageReady = {
                    pageReady = true
                    // 关键：若引擎在省电/LOW 档位下启动，冻结样式是在页面加载前
                    // 注入的（evaluateJavascript 落在空文档上，随后被新文档覆盖）。
                    // 页面就绪后必须重放冻结 + JS 暂停状态，否则省电承诺失效。
                    // rAF 门的间隔值同理会被导航重置，先解除去重标记强制重推。
                    pushedFrameInterval = -1L
                    applyWebViewLifecycle()
                },
            )
        } catch (t: Throwable) {
            Log.e(TAG, "create sandboxed webview failed", t)
            webView = null
        }
    }

    /**
     * WebView 生命周期的唯一裁决点（幂等）：
     * - CSS 冻结（省电 / LOW 档位）→ 注入/移除冻结样式；
     * - JS 定时器 → 冻结或不可见时 onPause，其余 onResume。
     * 所有状态变化（可见性 / 省电 / 档位 / 页面就绪）都收敛到这里，
     * 避免“resume 覆盖 freeze-pause”之类的状态互相踩踏。
     */
    private fun applyWebViewLifecycle() {
        refreshTier()
        val view = webView ?: return
        val wantFreeze = powerSave || tier.htmlFrozen
        if (wantFreeze != frozen) {
            frozen = wantFreeze
            view.evaluateJavascript(if (wantFreeze) FREEZE_JS else UNFREEZE_JS, null)
        }
        val wantJsPaused = !visible || wantFreeze
        if (wantJsPaused != jsPaused) {
            jsPaused = wantJsPaused
            if (wantJsPaused) view.onPause() else view.onResume()
        }
        // MEDIUM 档位 ~30fps 由页面内 rAF 门实现（SANDBOX_BOOT_JS 注入）；
        // LOW 档位已经 CSS 冻结 + JS 暂停（setTimeout 停摆，门自然停），归零即可。
        val frameInterval = if (wantJsPaused) 0L else tier.htmlFrameIntervalMs
        if (frameInterval != pushedFrameInterval) {
            pushedFrameInterval = frameInterval
            view.evaluateJavascript("window.__zunoFrameIntervalMs = $frameInterval;", null)
        }
    }

    /** 虚拟屏宿主：WebView 挂进这个“窗口”，渲染直接进入壁纸 Surface。 */
    private inner class HtmlPresentation(
        outerContext: Context,
        display: Display,
        private val view: WebView,
    ) : Presentation(outerContext, display) {

        override fun onCreate(savedInstanceState: Bundle?) {
            super.onCreate(savedInstanceState)
            // 黑底：页面加载完成前的底色与壁纸背景一致（OPAQUE surface）。
            window?.setBackgroundDrawable(ColorDrawable(Color.BLACK))
            setContentView(view)
        }
    }
}
