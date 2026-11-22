package com.zuno.wallpaper.wallpaper.gl

import android.opengl.EGL14
import android.opengl.EGLConfig
import android.opengl.EGLContext
import android.opengl.EGLDisplay
import android.opengl.EGLSurface
import android.os.Handler
import android.os.HandlerThread
import android.os.SystemClock
import android.view.Choreographer
import android.view.SurfaceHolder

/**
 * 深度视差壁纸的最小化 EGL 渲染线程。
 *
 * 为什么自建 EGL 而不用 GLSurfaceView：
 * 1. WallpaperService 的 Surface 不属于任何 View 层级，GLSurfaceView 无法挂载；
 * 2. 自建线程让我们完全掌控帧节奏（30/20/15fps 档位）与可见性暂停，
 *    省电模式下降帧只是改一个数字，不需要重建渲染管线；
 * 3. EGL14（minSdk 24 起可用）直接走系统 EGL，无额外依赖。
 *
 * 帧节奏：Choreographer 与显示 vsync 对齐（避免撕裂与无效帧），
 * 但只有 `now >= nextFrameAt` 才真正 swap，实现帧率上限；
 * 使用漂移修正（+= interval 而非 now + interval）保证长期平均帧率精确。
 */
class GlRenderThread(
    private val holder: SurfaceHolder,
    private val renderer: ParallaxRenderer,
    // 把倾斜值写入调用方提供的复用数组：渲染循环里禁止任何对象分配
    // （Pair 每帧分配会产生稳定的 GC 压力，与零分配设计相悖）。
    private val tiltSink: (FloatArray) -> Unit,
    // 内容是否在移动（倾斜在变化）。静止时帧率自动降到 15fps 上限——
    // 手机平放桌面时视差壁纸完全静止，30fps 的重绘是纯浪费。
    private val movingProvider: () -> Boolean,
    // GL 丢失回调：EGL 初始化失败 / swap 失败 / draw 异常后触发。
    // 没有它，Engine 侧以为线程还活着，壁纸会永久黑屏直到热切换。
    private val onLost: () -> Unit,
) : HandlerThread("zuno-gl") {

    companion object {
        /** 静止时的帧率上限（再低会看到明显的帧间跳变）。 */
        private const val STILL_FPS = 15
    }

    @Volatile private var paused = true
    @Volatile private var targetFps = 30
    @Volatile private var disposed = false

    // GL 线程写、主线程 shutdown() 读：volatile 保证可见性。非 volatile 时
    // shutdown 可能读到 null，EGL 资源（display/context/surface）永远得不到
    // 清理——GL 丢失重建风暴场景下会累积成可观的显存泄漏。
    @Volatile private var handler: Handler? = null
    @Volatile private var choreographer: Choreographer? = null

    private var display: EGLDisplay? = null
    private var context: EGLContext? = null
    private var surface: EGLSurface? = null
    private var glReady = false

    // 帧回调链是否活着。只在 GL 线程读写（resumeChain 同样 post 到 GL 线程），
    // 检查与置位在同一线程串行，杜绝双重投递。
    private var chainRunning = false

    private var nextFrameAt = 0L

    /** 复用的倾斜值缓冲：GL 线程每帧写入读取，不分配。 */
    private val tiltBuffer = FloatArray(2)

    private val frameCallback = object : Choreographer.FrameCallback {
        override fun doFrame(frameTimeNanos: Long) {
            if (disposed) return
            if (paused || !glReady) {
                // 暂停即断链：不可见时不再每 vsync 空跑一次回调（60Hz 纯唤醒
                // 无渲染，一小时 ~20 万次）。恢复由 setPaused(false) 重启。
                chainRunning = false
                return
            }
            val now = SystemClock.uptimeMillis()
            if (now >= nextFrameAt) {
                nextFrameAt = if (now - nextFrameAt > 200) {
                    // 唤醒/长时间暂停后重置节奏，避免连发补帧。
                    now + frameIntervalMs()
                } else {
                    nextFrameAt + frameIntervalMs()
                }
                renderOnce()
            }
            choreographer?.postFrameCallback(this)
        }
    }

    fun startRender(viewWidth: Int, viewHeight: Int) {
        start()
        handler = Handler(looper)
        handler?.post {
            // shutdown 可能与本初始化竞争（start 后立刻被 stopGl）：
            // 已 disposed 就不做任何 EGL/Choreographer 初始化，交给 shutdown 收尾。
            if (disposed) return@post
            choreographer = Choreographer.getInstance()
            glReady = initEgl()
            if (glReady && viewWidth > 0 && viewHeight > 0) {
                try {
                    renderer.setup(viewWidth, viewHeight)
                    // 初始状态为可见时直接起链（setPaused(false) 若先于本块执行，
                    // 它的 resumeChain 会因 glReady=false 而空跑，链由这里补启）。
                    if (!paused) {
                        chainRunning = true
                        choreographer?.postFrameCallback(frameCallback)
                    }
                } catch (t: Throwable) {
                    // 素材缺失/损坏（如包文件被系统清理）绝不能带崩整个进程：
                    // 记录日志并通知 Engine 走重建路径。
                    android.util.Log.e("ZunoGL", "renderer setup failed", t)
                    glReady = false
                    onLost()
                }
            } else if (!glReady) {
                onLost()
            }
        }
    }

    fun setPaused(value: Boolean) {
        if (paused == value) return
        paused = value
        if (!value) resumeChain()
    }

    /** 恢复帧回调链（GL 线程上执行；幂等）。 */
    private fun resumeChain() {
        handler?.post {
            if (disposed || paused || chainRunning || !glReady) return@post
            chainRunning = true
            choreographer?.postFrameCallback(frameCallback)
        }
    }

    fun setTargetFps(fps: Int) {
        targetFps = fps.coerceIn(5, 60)
    }

    private fun frameIntervalMs(): Long = 1000L / effectiveFps()

    /** 档位帧率与“静止降帧”的合成：静止时压到 STILL_FPS，动态时回到档位帧率。 */
    private fun effectiveFps(): Int =
        if (movingProvider()) targetFps else minOf(targetFps, STILL_FPS)

    /** @return 本帧是否成功提交到 Surface。 */
    private fun renderOnce(): Boolean {
        val d = display ?: return false
        val s = surface ?: return false
        val c = context ?: return false
        if (EGL14.eglGetCurrentContext() !== c && !EGL14.eglMakeCurrent(d, s, s, c)) {
            // 上下文丢失（GPU 复位/驱动重置）且重挂也失败：与 swap 失败同等
            // 对待——断链并通知 Engine 走重建。此前静默 return false 会让
            // 帧链继续空转（Choreographer 每 vsync 醒一次、什么也不画），
            // 深度壁纸永久黑屏且没有任何恢复事件。
            android.util.Log.e(
                "ZunoGL",
                "renderOnce: eglMakeCurrent failed err=0x${Integer.toHexString(EGL14.eglGetError())}",
            )
            glReady = false
            onLost()
            return false
        }
        try {
            tiltSink(tiltBuffer)
            renderer.draw(tiltBuffer[0], tiltBuffer[1])
        } catch (t: Throwable) {
            // draw 阶段的异常同样不能带崩进程（GL 状态损坏时直接停帧等重建）。
            android.util.Log.e("ZunoGL", "render failed", t)
            glReady = false
            onLost()
            return false
        }
        if (!EGL14.eglSwapBuffers(d, s)) {
            // Surface 被系统回收（例如转屏）；停止循环并通知 Engine 重建。
            android.util.Log.e("ZunoGL", "eglSwapBuffers failed err=0x${Integer.toHexString(EGL14.eglGetError())}")
            glReady = false
            onLost()
            return false
        }
        return true
    }

    /** EGL 初始化：RGB888、无深度/模板缓冲（2D 全屏 pass 用不上，省显存）。
     *  逐步失败日志：模拟器（gfxstream 等图形后端）对壁纸 Surface 的 EGL 支持
     *  存在兼容性差异，静默失败会导致“黑屏 + 无任何日志”无法排查。 */
    private fun initEgl(): Boolean {
        val d = EGL14.eglGetDisplay(EGL14.EGL_DEFAULT_DISPLAY)
        if (d == EGL14.EGL_NO_DISPLAY) {
            android.util.Log.e("ZunoGL", "initEgl: eglGetDisplay -> EGL_NO_DISPLAY")
            return false
        }
        val version = IntArray(2)
        if (!EGL14.eglInitialize(d, version, 0, version, 1)) {
            android.util.Log.e("ZunoGL", "initEgl: eglInitialize failed err=0x${Integer.toHexString(EGL14.eglGetError())}")
            return false
        }

        val attribs = intArrayOf(
            EGL14.EGL_RED_SIZE, 8,
            EGL14.EGL_GREEN_SIZE, 8,
            EGL14.EGL_BLUE_SIZE, 8,
            EGL14.EGL_ALPHA_SIZE, 0,
            EGL14.EGL_DEPTH_SIZE, 0,
            EGL14.EGL_STENCIL_SIZE, 0,
            EGL14.EGL_RENDERABLE_TYPE, EGL14.EGL_OPENGL_ES2_BIT,
            EGL14.EGL_SURFACE_TYPE, EGL14.EGL_WINDOW_BIT,
            EGL14.EGL_NONE,
        )
        val configs = arrayOfNulls<EGLConfig>(1)
        val numConfigs = IntArray(1)
        if (!EGL14.eglChooseConfig(d, attribs, 0, configs, 0, 1, numConfigs, 0) || numConfigs[0] == 0) {
            android.util.Log.e("ZunoGL", "initEgl: eglChooseConfig 0 configs err=0x${Integer.toHexString(EGL14.eglGetError())}")
            return false
        }
        val ctxAttribs = intArrayOf(EGL14.EGL_CONTEXT_CLIENT_VERSION, 2, EGL14.EGL_NONE)
        val ctx = EGL14.eglCreateContext(d, configs[0], EGL14.EGL_NO_CONTEXT, ctxAttribs, 0)
        if (ctx == EGL14.EGL_NO_CONTEXT) {
            android.util.Log.e("ZunoGL", "initEgl: eglCreateContext failed err=0x${Integer.toHexString(EGL14.eglGetError())}")
            return false
        }

        val surf = EGL14.eglCreateWindowSurface(d, configs[0], holder.surface, intArrayOf(EGL14.EGL_NONE), 0)
        if (surf == null || surf == EGL14.EGL_NO_SURFACE) {
            android.util.Log.e(
                "ZunoGL",
                "initEgl: eglCreateWindowSurface failed err=0x${Integer.toHexString(EGL14.eglGetError())} surfaceValid=${holder.surface?.isValid}",
            )
            EGL14.eglDestroyContext(d, ctx)
            return false
        }
        if (!EGL14.eglMakeCurrent(d, surf, surf, ctx)) {
            android.util.Log.e("ZunoGL", "initEgl: eglMakeCurrent failed err=0x${Integer.toHexString(EGL14.eglGetError())}")
            EGL14.eglDestroySurface(d, surf)
            EGL14.eglDestroyContext(d, ctx)
            return false
        }

        display = d
        context = ctx
        surface = surf
        android.util.Log.i("ZunoGL", "initEgl ok, EGL ${version[0]}.${version[1]}")
        return true
    }

    fun shutdown() {
        disposed = true
        choreographer?.let { c ->
            handler?.post { c.removeFrameCallback(frameCallback) }
        }
        handler?.post {
            val d = display
            val s = surface
            val c = context
            if (d != null && d != EGL14.EGL_NO_DISPLAY) {
                if (s != null && s != EGL14.EGL_NO_SURFACE) EGL14.eglDestroySurface(d, s)
                if (c != null && c != EGL14.EGL_NO_CONTEXT) EGL14.eglDestroyContext(d, c)
                EGL14.eglReleaseThread()
                // 注意：绝不 eglTerminate(d)。EGL_DEFAULT_DISPLAY 是进程级单例，
                // Flutter（Impeller）、WebView 等都在同一个 display 上持有 EGL
                // 资源；terminate 会把它们一并作废，表现为销毁深度壁纸后其它
                // GL 内容闪烁/黑屏。Surface/Context 逐个销毁即可完全释放本引擎
                // 占用的资源。
            }
            renderer.teardown()
            glReady = false
        }
        quitSafely()
        try {
            // EGL/纹理销毁是毫秒级操作；250ms 只是兜底上限。
            // 注意 shutdown 由主线程（Engine 回调）调用，不能阻塞过久。
            join(250)
        } catch (_: InterruptedException) {
            Thread.currentThread().interrupt()
        }
    }
}
