package com.zuno.wallpaper.flutter

import android.content.Context
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.FlutterEngineGroup

/**
 * 壁纸运行时的 FlutterEngine 附着点（架构扩展位）。
 *
 * 当前四种壁纸类型（video/depth/html/timed）**全部不经过 Flutter 渲染链路**：
 * 视频走 ExoPlayer（可切硬/软解）、深度视差走原生 GLES、HTML 走原生 WebView。
 * 这是刻意的性能决策：Flutter raster 线程 + Texture 跨 Context 拷贝对壁纸级
 * 常驻渲染是纯开销。
 *
 * 但架构上保留“场景壁纸需要 Flutter Widget 层做交互容器”的能力（规格要求）：
 * 当未来出现 flutter 类型的壁纸时，从这里获取一个独立、长期存活的 FlutterEngine
 * （FlutterEngineGroup 创建与缓存，避免每次切换壁纸重建引擎的秒级开销），
 * 再由调用方把引擎渲染接入自己的绘制管线。
 *
 * 使用方式：
 * ```kotlin
 * val engine = FlutterEngineHolder.obtain(context) // 惰性创建，进程级缓存
 * // ... 把 engine 接入渲染（dartExecutor 执行入口、renderer 输出到 Surface 等）
 * ```
 */
object FlutterEngineHolder {

    @Volatile private var engine: FlutterEngine? = null
    @Volatile private var group: FlutterEngineGroup? = null

    /**
     * 获取（或创建）长期存活的 headless FlutterEngine。
     * createAndRunDefaultEngine：创建后立即运行 "main" 入口，但不 attach 到任何
     * Activity/View —— headless 运行，适合壁纸这种无 Activity 的宿主。
     */
    @Synchronized
    fun obtain(context: Context): FlutterEngine {
        engine?.let { return it }
        val g = group ?: FlutterEngineGroup(context.applicationContext).also { group = it }
        val created = g.createAndRunDefaultEngine(context.applicationContext)
        engine = created
        return created
    }

    /** 进程退出或不再需要 Widget 层壁纸时释放（Engine.onDestroy 不应频繁调用）。 */
    @Synchronized
    fun release() {
        engine?.destroy()
        engine = null
    }
}
