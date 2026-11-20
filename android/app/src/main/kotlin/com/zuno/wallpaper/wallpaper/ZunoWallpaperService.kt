package com.zuno.wallpaper.wallpaper

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.PowerManager
import android.service.wallpaper.WallpaperService
import android.view.MotionEvent
import android.view.SurfaceHolder
import com.zuno.wallpaper.wallpaper.engine.DepthWallpaperEngine
import com.zuno.wallpaper.wallpaper.engine.HtmlWallpaperEngine
import com.zuno.wallpaper.wallpaper.engine.VideoWallpaperEngine
import com.zuno.wallpaper.wallpaper.engine.WallpaperEngineDelegate

/**
 * ZUNO 壁纸渲染宿主。
 *
 * 职责边界（渲染与生命周期严格分离）：
 * - Engine 自身只做生命周期调度：Surface 事件 / 可见性 / 省电模式 / 热切换，
 *   并把事件转发给按壁纸类型选择的 [WallpaperEngineDelegate]。
 * - 真正的渲染在 delegate 中：视频 → 原生 ExoPlayer（可切硬/软解）；深度视差 → 原生 OpenGL ES；
 *   HTML → 离屏 WebView 软件绘制。四种类型没有一种经过 Flutter 渲染链路
 *   （见 README「架构」一节：Flutter 只做管理端 UI）。
 */
class ZunoWallpaperService : WallpaperService() {

    override fun onCreateEngine(): Engine = ZunoEngine()

    inner class ZunoEngine : Engine() {

        private var delegate: WallpaperEngineDelegate? = null

        /** 当前 delegate 对应的激活记录：热切换去重与“仅参数变化”判定依据。 */
        private var lastApplied: ActiveWallpaper? = null

        private val mainHandler = Handler(Looper.getMainLooper())

        // ---------- 省电模式 ----------
        // 为什么动态注册且只在可见时注册：ACTION_POWER_SAVE_MODE_CHANGED 是低频系统广播，
        // 壁纸不可见时 Engine 本来就不渲染，没必要让接收器活着（最小化常驻开销）。
        // 注册时机与可见性绑定，同时必须在“恢复可见”时主动同步一次当前省电状态——
        // 广播只发给在注册的接收器，不可见期间切换的省电模式不会被补发。
        private val powerSaveReceiver = object : BroadcastReceiver() {
            override fun onReceive(context: Context, intent: Intent) {
                forwardPowerSaveState()
            }
        }
        private var powerSaveReceiverRegistered = false

        private fun forwardPowerSaveState() {
            val pm = getSystemService(Context.POWER_SERVICE) as PowerManager
            delegate?.onPowerSaveChanged(pm.isPowerSaveMode)
        }

        private fun registerPowerSaveReceiver() {
            if (powerSaveReceiverRegistered) return
            val filter = IntentFilter(PowerManager.ACTION_POWER_SAVE_MODE_CHANGED)
            if (Build.VERSION.SDK_INT >= 33) {
                registerReceiver(powerSaveReceiver, filter, Context.RECEIVER_NOT_EXPORTED)
            } else {
                registerReceiver(powerSaveReceiver, filter)
            }
            powerSaveReceiverRegistered = true
        }

        private fun unregisterPowerSaveReceiver() {
            if (!powerSaveReceiverRegistered) return
            runCatching { unregisterReceiver(powerSaveReceiver) }
            powerSaveReceiverRegistered = false
        }

        // ---------- 热切换（ConfigBus） ----------
        // ConfigBus 事件可能来自 WorkManager 的后台线程，必须 post 到主线程再动 delegate。
        private val configListener: (ConfigBus.Event) -> Unit = { event ->
            mainHandler.post {
                when (event) {
                    ConfigBus.Event.WALLPAPER_CHANGED -> rebuildDelegate()
                    ConfigBus.Event.CONFIG_CHANGED -> {
                        // 参数与性能档位变化都走本事件：始终转发给 delegate
                        // （各引擎的 onConfigChanged 同时负责按新档位调整自身行为）。
                        val w = ActiveWallpaperStore.load(this@ZunoWallpaperService)
                        if (w != null) delegate?.onConfigChanged(w.configJson)
                    }
                }
            }
        }

        override fun onCreate(holder: SurfaceHolder) {
            super.onCreate(holder)
            // 壁纸内容均不透明：OPAQUE 让系统合成器走最高效路径，也避免黑帧闪烁。
            holder.setFormat(android.graphics.PixelFormat.OPAQUE)
            ConfigBus.addListener(configListener)
            rebuildDelegate()
        }

        private fun rebuildDelegate() {
            val active = ActiveWallpaperStore.load(this@ZunoWallpaperService)
            val cached = lastApplied
            // 热切换去重：用户对同一壁纸重复“应用”（参数也没变）时，重建只会白白
            // 销毁已就绪的渲染状态（HTML 的 WebView 页面缓存尤其昂贵）。
            if (active == cached && delegate != null) return
            // 同一渲染单元（id/dir/entry/能力不变）仅参数更新：推送配置即可，
            // 不走销毁-重建路径。
            if (cached != null && active != null &&
                active.id == cached.id &&
                active.dir == cached.dir &&
                active.entry == cached.entry &&
                active.capabilitiesJson == cached.capabilitiesJson
            ) {
                delegate?.onConfigChanged(active.configJson)
                lastApplied = active
                return
            }
            // timed 类型本身不渲染（激活的已经是某个 slot 子壁纸），type 必为三种可渲染类型之一。
            delegate?.onDestroy()
            delegate = when (active?.type) {
                "video" -> VideoWallpaperEngine(this@ZunoWallpaperService, active)
                "depth" -> DepthWallpaperEngine(this@ZunoWallpaperService, active)
                "html" -> HtmlWallpaperEngine(this@ZunoWallpaperService, active)
                else -> null
            }
            lastApplied = active
            // 热切换重建时 Surface 可能已经存在：补发状态，保证新 delegate 直接进入可用画面。
            // 顺序与框架一致（surface → visibility），最后补省电状态——新 delegate 不能假设
            // 初始为非省电模式。
            delegate?.onSurfaceCreated(surfaceHolder)
            delegate?.onVisibilityChanged(isVisible)
            forwardPowerSaveState()
            // HTML 壁纸需要接收触摸（Engine 默认不投递触摸事件）。
            setTouchEventsEnabled(active?.type == "html")
        }

        override fun onVisibilityChanged(visible: Boolean) {
            super.onVisibilityChanged(visible)
            // 顺序关键：先让 delegate 对齐可见性（video 可能 start/pause、GL/HTML
            // 停止或恢复渲染），再同步省电状态。反过来会在“即将隐藏”的瞬间触发
            // 一次多余的 start，然后再立刻 pause。
            delegate?.onVisibilityChanged(visible)
            if (visible) {
                // 恢复可见：注册接收器，并主动同步一次省电状态（补上不可见期间
                // 错过的模式切换）。
                registerPowerSaveReceiver()
                forwardPowerSaveState()
            } else {
                unregisterPowerSaveReceiver()
            }
        }

        override fun onSurfaceCreated(holder: SurfaceHolder) {
            super.onSurfaceCreated(holder)
            delegate?.onSurfaceCreated(holder)
        }

        override fun onSurfaceChanged(holder: SurfaceHolder, format: Int, width: Int, height: Int) {
            super.onSurfaceChanged(holder, format, width, height)
            delegate?.onSurfaceChanged(holder, format, width, height)
        }

        override fun onSurfaceDestroyed(holder: SurfaceHolder) {
            // 回调返回后 Surface 即失效：delegate 必须在此同步解除对 Surface 的占用。
            delegate?.onSurfaceDestroyed(holder)
            super.onSurfaceDestroyed(holder)
        }

        override fun onSurfaceRedrawNeeded(holder: SurfaceHolder) {
            super.onSurfaceRedrawNeeded(holder)
            // 系统要求重绘当前帧（亮屏/解锁等场景）——按需重绘的路径
            // （HTML 静态页）依赖此回调，否则显示花屏/黑帧。
            delegate?.onSurfaceRedrawNeeded(holder)
        }

        override fun onComputeColors(): android.app.WallpaperColors? {
            // Material You 主题取色：交给各类型实现（颜色图/视频首帧主导色）。
            // delegate 未实现（HTML）或无激活壁纸时返回 null = 系统默认处理。
            return delegate?.onComputeColors() ?: super.onComputeColors()
        }

        override fun onTouchEvent(event: MotionEvent) {
            delegate?.onTouchEvent(event)
            super.onTouchEvent(event)
        }

        override fun onDestroy() {
            unregisterPowerSaveReceiver()
            ConfigBus.removeListener(configListener)
            delegate?.onDestroy()
            delegate = null
            super.onDestroy()
        }
    }
}
