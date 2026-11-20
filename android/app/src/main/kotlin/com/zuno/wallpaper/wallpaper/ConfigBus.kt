package com.zuno.wallpaper.wallpaper

import java.util.concurrent.CopyOnWriteArrayList

/**
 * 进程内配置事件总线。
 *
 * 为什么存在：ZUNO 的 WallpaperService 与主 App、WorkManager Worker 运行在同一个进程
 * （manifest 中未声明 android:process）。当 Dart 侧“应用壁纸”或 timed Worker 切换时段时，
 * 只需要更新 SharedPreferences，再通过这里广播一次事件，正在运行的 Engine 即可就地
 * 热切换渲染内容——不需要重新走 WallpaperManager 应用流程（普通应用没有
 * SET_WALLPAPER_COMPONENT 权限，也无法直接重设组件）。
 *
 * 监听方负责自己切线程：Engine 在主线程渲染，Worker 在 WorkManager 的后台线程发出事件，
 * 所以 Engine 侧会用 Handler post 到主线程（见 ZunoWallpaperService）。
 */
object ConfigBus {

    enum class Event {
        /** 当前激活壁纸（id/dir/entry/type）发生了变化。 */
        WALLPAPER_CHANGED,

        /** 当前壁纸的用户可调参数（config JSON）发生了变化。 */
        CONFIG_CHANGED,
    }

    private val listeners = CopyOnWriteArrayList<(Event) -> Unit>()

    fun addListener(listener: (Event) -> Unit) {
        listeners.add(listener)
    }

    fun removeListener(listener: (Event) -> Unit) {
        listeners.remove(listener)
    }

    fun emit(event: Event) {
        // CopyOnWriteArrayList：遍历时无需加锁，监听器抛异常不影响其他监听器。
        for (l in listeners) {
            runCatching { l(event) }
        }
    }
}
