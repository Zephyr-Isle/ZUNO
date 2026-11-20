package com.zuno.wallpaper

import android.app.Application
import com.zuno.wallpaper.wallpaper.timed.TimedWallpaperScheduler

/**
 * ZUNO 的 Application。
 *
 * 只在启动时确保 timed 壁纸的周期任务已注册（幂等，ExistingPeriodicWorkPolicy.KEEP）。
 * WorkManager 会在进程死亡 / 设备重启后自动恢复任务，这里不需要额外逻辑。
 */
class ZunoApplication : Application() {

    override fun onCreate() {
        super.onCreate()
        TimedWallpaperScheduler.ensureScheduled(this)
    }
}
