package com.zuno.wallpaper.wallpaper.engine

import android.app.WallpaperColors
import android.view.MotionEvent
import android.view.SurfaceHolder

/**
 * 按壁纸类型实现的渲染委托接口。
 *
 * ZunoWallpaperService.Engine 把生命周期事件原样转发给 delegate，
 * delegate 之间互不感知，保证每条渲染路径的依赖与线程模型完全独立：
 * - VideoWallpaperEngine：主线程 ExoPlayer（可选择硬解/软解）。
 * - DepthWallpaperEngine：专用 GL 线程（EGL14）+ 主线程传感器监听。
 * - HtmlWallpaperEngine：主线程离屏 WebView + 软件画布绘制。
 */
interface WallpaperEngineDelegate {

    fun onSurfaceCreated(holder: SurfaceHolder)

    fun onSurfaceChanged(holder: SurfaceHolder, format: Int, width: Int, height: Int)

    /**
     * Surface 即将被销毁。框架在回调返回后才真正销毁 Surface，
     * 因此各实现必须在此同步释放对 Surface 的引用（暂停 GL / 解绑播放器）。
     */
    fun onSurfaceDestroyed(holder: SurfaceHolder)

    /** 功耗控制枢纽：visible=false 时必须停止一切渲染与传感器监听（见各实现）。 */
    fun onVisibilityChanged(visible: Boolean)

    /** 系统省电模式切换（PowerManager.ACTION_POWER_SAVE_MODE_CHANGED）。 */
    fun onPowerSaveChanged(powerSave: Boolean)

    /** 仅 HTML 壁纸会收到（setTouchEventsEnabled(true)）。 */
    fun onTouchEvent(event: MotionEvent)

    /** 用户可调参数变化（整份 config JSON）。 */
    fun onConfigChanged(configJson: String)

    /**
     * 系统要求重绘当前帧（亮屏/解锁后 Surface 缓冲可能被清）。
     * 持续渲染的路径可忽略；按需重绘的路径（HTML 静态页）必须实现。
     */
    fun onSurfaceRedrawNeeded(holder: SurfaceHolder) {}

    /**
     * 系统提取主题色（Material You 启动器/锁屏着色）。
     * 返回 null = 交给系统默认处理。仅 API 27+ 有意义（WallpaperColors API 级别）。
     */
    fun onComputeColors(): WallpaperColors? = null

    fun onDestroy()
}
