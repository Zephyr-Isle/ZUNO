package com.zuno.wallpaper.wallpaper.engine

import android.content.Context
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import android.util.Log
import android.view.MotionEvent
import android.view.SurfaceHolder
import com.zuno.wallpaper.wallpaper.ActiveWallpaper
import com.zuno.wallpaper.wallpaper.ActiveWallpaperStore
import com.zuno.wallpaper.wallpaper.PerformanceTier
import com.zuno.wallpaper.wallpaper.gl.GlRenderThread
import com.zuno.wallpaper.wallpaper.gl.ParallaxRenderer
import org.json.JSONObject
import java.io.File
import kotlin.math.abs
import kotlin.math.sqrt

/**
 * 深度视差壁纸：OpenGL ES 直接渲染颜色图 + 深度图。
 *
 * 帧率档位（PerformanceTier）：高=30fps、中=20fps、低=15fps；省电模式强制 15fps。
 * 为什么视差不需要 60fps：位移来自重力方向变化，变化率本身低（低通滤波后），
 * 30fps 已超过人眼对这种缓慢平移的感知极限；每降 10fps 都显著降低 GPU/CPU 占用。
 *
 * 传感器：加速度计给出绝对重力方向（低通滤波去除手抖噪声）；
 * 陀螺仪旋转速率做衰减积分，提供“快速甩动”的瞬态响应。两者都在主线程回调里做
 * 滤波（SensorManager UI 档回调 ~60Hz，开销可忽略），GL 线程只读两个 volatile float，
 * 不发生锁竞争或每帧对象分配。
 */
class DepthWallpaperEngine(
    private val context: Context,
    private val wallpaper: ActiveWallpaper,
) : WallpaperEngineDelegate {

    companion object {
        private const val TAG = "ZunoDepth"
        private const val LPF_ALPHA = 0.15f
        private const val GYRO_GAIN = 0.9f
        private const val GYRO_DECAY = 0.88f
        private const val POWER_SAVE_FPS = 15

        /** 倾斜变化量低于该值视为“没动”（LPF 收敛后仍有微噪声，阈值要压住它）。 */
        private const val STILL_EPSILON = 0.004f

        /** 距上次倾斜变化超过该时长即认为设备静止 → GL 帧率自动降到 15fps。 */
        private const val STILL_AFTER_MS = 2000L
    }

    private val sensorManager = context.getSystemService(Context.SENSOR_SERVICE) as SensorManager
    private val accelSensor: Sensor? = sensorManager.getDefaultSensor(Sensor.TYPE_ACCELEROMETER)
    private val gyroSensor: Sensor? = sensorManager.getDefaultSensor(Sensor.TYPE_GYROSCOPE)

    // 低通滤波状态。主线程写，GL 线程读：两个拆开的 volatile float 保证可见性，
    // 避免每次传感器回调分配 FloatArray 或加锁。
    @Volatile private var tiltX = 0f
    @Volatile private var tiltY = 0f
    private var smoothAx = 0f
    private var smoothAy = 0f
    private var gyroBoostX = 0f
    private var gyroBoostY = 0f
    private var lastGyroAt = 0L

    // ---------- 静止检测（驱动 GL 线程静止降帧） ----------
    @Volatile private var lastTiltChangeAt = 0L
    private var stillCheckX = 0f
    private var stillCheckY = 0f

    private var glThread: GlRenderThread? = null
    // 持有渲染器引用：onConfigChanged 热切换 parallax_strength 时直接推送，
    // 不需要销毁重建 GL 线程（strength 是 @Volatile，跨线程可见）。
    private var renderer: ParallaxRenderer? = null
    private var holder: SurfaceHolder? = null
    private var surfaceReady = false
    private var visible = false
    private var powerSave = false
    private var viewWidth = 0
    private var viewHeight = 0
    private var sensorsRegistered = false

    private var parallaxStrength = 0.06f

    private val tier: PerformanceTier
        get() = PerformanceTier.parse(ActiveWallpaperStore.performanceTier(context))

    private val sensorListener = object : SensorEventListener {
        override fun onSensorChanged(event: SensorEvent) {
            when (event.sensor.type) {
                Sensor.TYPE_ACCELEROMETER -> {
                    // 归一化重力向量 → 屏幕平面内的倾斜分量（x 向右，y 向下）。
                    val gx = event.values[0]
                    val gy = event.values[1]
                    val gz = event.values[2]
                    val norm = sqrt(gx * gx + gy * gy + gz * gz)
                    if (norm < 0.001f) return
                    val targetX = (gx / norm).coerceIn(-1f, 1f)
                    val targetY = (gy / norm).coerceIn(-1f, 1f)
                    // 一阶低通滤波：smooth = smooth + (raw - smooth) * α。
                    // 直接用原始值会让壁纸随微抖动高频晃动，既伤眼又费电。
                    smoothAx += (targetX - smoothAx) * LPF_ALPHA
                    smoothAy += (targetY - smoothAy) * LPF_ALPHA
                    tiltX = (smoothAx + gyroBoostX).coerceIn(-1f, 1f)
                    tiltY = (smoothAy + gyroBoostY).coerceIn(-1f, 1f)
                    // 静止检测：变化量越过阈值才刷新时间戳（LPF 收敛后微噪声不触发）。
                    if (abs(tiltX - stillCheckX) > STILL_EPSILON ||
                        abs(tiltY - stillCheckY) > STILL_EPSILON
                    ) {
                        stillCheckX = tiltX
                        stillCheckY = tiltY
                        lastTiltChangeAt = System.currentTimeMillis()
                    }
                }
                Sensor.TYPE_GYROSCOPE -> {
                    val now = System.currentTimeMillis()
                    val dt = if (lastGyroAt == 0L) 0.016f else (now - lastGyroAt) / 1000f
                    lastGyroAt = now
                    // 旋转速率 × 时间 = 角度增量；乘增益并指数衰减，只保留瞬态“甩动”。
                    gyroBoostX = (gyroBoostX * GYRO_DECAY + event.values[0] * dt * GYRO_GAIN)
                        .coerceIn(-0.5f, 0.5f)
                    gyroBoostY = (gyroBoostY * GYRO_DECAY - event.values[1] * dt * GYRO_GAIN)
                        .coerceIn(-0.5f, 0.5f)
                    if (abs(gyroBoostX) < 0.002f) gyroBoostX = 0f
                    if (abs(gyroBoostY) < 0.002f) gyroBoostY = 0f
                }
            }
        }

        override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) = Unit
    }

    // ---------- 生命周期 ----------

    override fun onSurfaceCreated(holder: SurfaceHolder) {
        this.holder = holder
        surfaceReady = holder.surface?.isValid == true
        viewWidth = holder.surfaceFrame.width()
        viewHeight = holder.surfaceFrame.height()
        startGlIfNeeded()
    }

    override fun onSurfaceChanged(holder: SurfaceHolder, format: Int, width: Int, height: Int) {
        this.holder = holder
        // 壁纸 Surface 尺寸变化（少见，如转屏）：重建 GL 线程以匹配新的窗口 Surface。
        if (width != viewWidth || height != viewHeight) {
            viewWidth = width
            viewHeight = height
            stopGlDeliberate()
            startGlIfNeeded()
        }
    }

    override fun onSurfaceDestroyed(holder: SurfaceHolder) {
        surfaceReady = false
        stopGlDeliberate()
        unregisterSensors()
    }

    override fun onVisibilityChanged(visible: Boolean) {
        this.visible = visible
        if (visible) {
            startGlIfNeeded()
            registerSensors()
            // 关键修复：线程可能在“不可见”期间创建（应用流程中系统绑定时
            // 壁纸被选择器遮挡），startGlIfNeeded 会因线程已存在而跳过——
            // 恢复可见时必须显式解除暂停，否则线程永远 paused（黑屏）。
            glThread?.setPaused(false)
            // 省电/档位可能在不可见期间变化过，这里对齐一次。
            glThread?.setTargetFps(if (powerSave) POWER_SAVE_FPS else tier.depthFps)
        } else {
            // 功耗枢纽：不可见 = 零渲染 + 零传感器（规格要求）。
            glThread?.setPaused(true)
            unregisterSensors()
        }
    }

    override fun onPowerSaveChanged(powerSave: Boolean) {
        this.powerSave = powerSave
        // 规格：省电模式强制降到 15fps；否则回到档位对应帧率。
        glThread?.setTargetFps(if (powerSave) POWER_SAVE_FPS else tier.depthFps)
    }

    override fun onTouchEvent(event: MotionEvent) = Unit

    override fun onConfigChanged(configJson: String) {
        parallaxStrength = parseStrength(configJson)
        // 热切换强度必须推给运行中的渲染器：之前只更新成员字段，
        // GL 线程仍用启动时的旧值渲染，用户调参不生效直到引擎重建。
        renderer?.setStrength(parallaxStrength)
        // 性能档位可能随本事件变化（setPerformanceTier 走同一事件）：
        // 省电模式优先，否则回到档位对应帧率。
        glThread?.setTargetFps(if (powerSave) POWER_SAVE_FPS else tier.depthFps)
    }

    override fun onDestroy() {
        stopGlDeliberate()
        unregisterSensors()
        cachedColors = null
    }

    // ---------- 主题色（Material You 启动器/锁屏着色） ----------

    private var cachedColors: android.app.WallpaperColors? = null

    /** 从颜色图（entry 指向的 jpg/png）提取 WallpaperColors，结果缓存。 */
    private fun computeColors(): android.app.WallpaperColors? {
        if (android.os.Build.VERSION.SDK_INT < 27) return null
        cachedColors?.let { return it }
        return try {
            val path = File(wallpaper.dir, wallpaper.entry).absolutePath
            val bounds = android.graphics.BitmapFactory.Options().apply {
                inJustDecodeBounds = true
            }
            android.graphics.BitmapFactory.decodeFile(path, bounds)
            if (bounds.outWidth <= 0) return null
            // 解码到 ~480px 内即可（取色不需要全尺寸）。
            var sample = 1
            while (bounds.outWidth / sample > 480 || bounds.outHeight / sample > 480) {
                sample *= 2
            }
            val bmp = android.graphics.BitmapFactory.decodeFile(
                path,
                android.graphics.BitmapFactory.Options().apply { inSampleSize = sample },
            ) ?: return null
            val colors = android.app.WallpaperColors.fromBitmap(bmp)
            bmp.recycle()
            cachedColors = colors
            colors
        } catch (t: Throwable) {
            Log.w(TAG, "depth colors compute failed", t)
            null
        }
    }

    override fun onComputeColors(): android.app.WallpaperColors? = computeColors()

    // ---------- 内部 ----------

    /**
     * 包内 parallax_strength × 设置页的全局倍率。
     * 全局倍率让用户不必逐个包调参，也能在“太晃/不够明显”时一键修正；
     * 最终上限与渲染器一致（0.2），避免过度位移采样到纹理外。
     */
    private fun parseStrength(configJson: String): Float {
        val base = runCatching {
            JSONObject(configJson).optDouble("parallax_strength", 0.06).toFloat()
        }.getOrDefault(0.06f)
        return (base * ActiveWallpaperStore.depthStrengthScale(context)).coerceIn(0f, 0.2f)
    }

    private fun startGlIfNeeded() {
        if (!surfaceReady || !visible || glThread != null) return
        val h = holder ?: return
        if (accelSensor == null && gyroSensor == null) {
            Log.w(TAG, "no sensors available, depth wallpaper renders as static image")
        }
        // 注意：parallaxStrength 以成员字段为准——onConfigChanged 会随参数/档位
        // 事件更新它；这里不能回读构造时的 wallpaper.configJson（陈旧值会覆盖
        // 用户运行中的调整）。
        parallaxStrength = parseStrength(
            ActiveWallpaperStore.load(context)?.configJson ?: wallpaper.configJson,
        )
        val colorPath = File(wallpaper.dir, wallpaper.entry).absolutePath
        // 规格固定：深度图 / 自定义着色器与颜色图同在包的 content/ 目录下。
        val depthPath = File(wallpaper.dir, "content/depth.png").absolutePath
        val shaderPath = File(wallpaper.dir, "content/shader.glsl").absolutePath
        // 入口素材缺失（包被清理/数据损坏）时直接不启动 GL 线程——
        // ParallaxRenderer.setup 抛异常现在也不会崩进程，但提前检查能省一次 EGL 初始化。
        if (!File(colorPath).isFile || !File(depthPath).isFile) {
            Log.w(TAG, "package assets missing ($colorPath / $depthPath), skip GL start")
            surfaceReady = false
            return
        }
        val renderer = ParallaxRenderer(colorPath, depthPath, shaderPath)
        renderer.setStrength(parallaxStrength)
        this.renderer = renderer
        val thread = GlRenderThread(
            h,
            renderer,
            tiltSink = { arr ->
                arr[0] = tiltX
                arr[1] = tiltY
            },
            movingProvider = {
                System.currentTimeMillis() - lastTiltChangeAt < STILL_AFTER_MS
            },
            onLost = { onGlLost() },
        )
        thread.setTargetFps(if (powerSave) POWER_SAVE_FPS else tier.depthFps)
        thread.setPaused(false)
        thread.startRender(viewWidth, viewHeight)
        glThread = thread
        // 启动阶段先按“移动中”处理：LPF 从 0 收敛到实际重力方向会触发变化时间戳，
        // 静止设备上几秒内自然降回 15fps。
        lastTiltChangeAt = System.currentTimeMillis()
    }

    /**
     * GL 丢失恢复（swap 失败 / 初始化失败 / draw 异常）：销毁线程并按指数退避重建。
     * 回调发生在 GL 线程，必须 post 回主线程再动 Engine 状态。
     *
     * 不能用"节流跳过"式实现：onLost 每个失败的线程只回调一次，被节流跳过
     * 之后没有任何事件会再次触发重建 —— 壁纸在第 2 次失败后永久黑屏（直到
     * 锁屏再亮屏或热切换）。这里改为**调度式**退避：每次失败都主动 postDelayed
     * 下一次重试，间隔 2s → 4s → … → 60s 封顶。瞬态故障（GPU 复位等）通常
     * 一次重试即恢复；确定性故障（素材损坏）退避到 60s，不会形成 2 秒一次
     * 的永久重建风暴。
     */
    private val mainHandler = android.os.Handler(android.os.Looper.getMainLooper())
    @Volatile private var glRebuildBackoffMs = 0L

    private fun onGlLost() {
        mainHandler.post {
            stopGl()
            val backoff = glRebuildBackoffMs
            glRebuildBackoffMs = if (backoff == 0L) 2_000L else (backoff * 2).coerceAtMost(60_000L)
            mainHandler.postDelayed({
                // 期间用户离开（surface 已销毁/不可见）或已由其它路径重建则跳过；
                // 恢复可见 / 尺寸变化会走 startGlIfNeeded 的正常启动路径。
                if (!visible || !surfaceReady || glThread != null) return@postDelayed
                startGlIfNeeded()
            }, backoff)
        }
    }

    /** 用户/系统主动销毁 GL（非故障路径）：退避计数归零，下次失败从头开始。 */
    private fun stopGlDeliberate() {
        mainHandler.removeCallbacksAndMessages(null)
        glRebuildBackoffMs = 0L
        stopGl()
    }

    private fun stopGl() {
        glThread?.shutdown()
        glThread = null
        renderer = null
    }

    private fun registerSensors() {
        if (sensorsRegistered) return
        // SENSOR_DELAY_UI：约 60Hz，与视差所需的平滑度匹配，比 GAME 低功耗。
        accelSensor?.let { sensorManager.registerListener(sensorListener, it, SensorManager.SENSOR_DELAY_UI) }
        gyroSensor?.let { sensorManager.registerListener(sensorListener, it, SensorManager.SENSOR_DELAY_UI) }
        sensorsRegistered = true
    }

    private fun unregisterSensors() {
        if (!sensorsRegistered) return
        sensorManager.unregisterListener(sensorListener)
        sensorsRegistered = false
    }
}
