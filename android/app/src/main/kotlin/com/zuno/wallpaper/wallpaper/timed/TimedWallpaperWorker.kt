package com.zuno.wallpaper.wallpaper.timed

import android.content.Context
import android.os.SystemClock
import androidx.work.ExistingPeriodicWorkPolicy
import androidx.work.ExistingWorkPolicy
import androidx.work.OneTimeWorkRequestBuilder
import androidx.work.PeriodicWorkRequestBuilder
import androidx.work.WorkManager
import androidx.work.Worker
import androidx.work.WorkerParameters
import androidx.work.workDataOf
import com.zuno.wallpaper.bridge.BatteryGuard
import com.zuno.wallpaper.wallpaper.ActiveWallpaper
import com.zuno.wallpaper.wallpaper.ActiveWallpaperStore
import com.zuno.wallpaper.wallpaper.ConfigBus
import java.io.File
import java.util.Calendar
import java.util.concurrent.TimeUnit

/**
 * timed 壁纸的“元调度器” Worker。
 *
 * 职责：周期性地重新解析当前激活 timed 包的 schedule.json，
 * 若应激活的 slot 与当前不同 → 更新 SharedPreferences + ConfigBus 热切换。
 *
 * 设计要点：
 * - 15 分钟是 WorkManager 周期任务的平台硬限制（BATCH 内部还会合并），所以
 *   schedule 的分钟级精度在 Doze 下不可保证——这是平台现实，README 有说明；
 * - minIntervalMinutes 节流：两次切换至少间隔 N 分钟，防止 15 分钟粒度 + 短窗口
 *   导致频繁切换（用户感知为壁纸闪烁）；
 * - 切换只发生在“当前系统壁纸就是本 timed 包”时（timedParentDir != null）；
 *   用户换了别的壁纸后，Worker 自动空转。
 */
class TimedWallpaperWorker(
    context: Context,
    params: WorkerParameters,
) : Worker(context, params) {

    override fun doWork(): Result {
        // 边界一次性任务带标记；周期兜底任务没有标记。
        val isBoundary = inputData.getBoolean(TimedWallpaperScheduler.KEY_BOUNDARY, false)
        return try {
            runOnce()
        } finally {
            // 执行完都要保证下一条边界任务存在，否则边界提醒断档。
            // 两条路径用不同策略，缺一不可：
            // - 边界任务续排必须 APPEND_OR_REPLACE：REPLACE 会把仍在运行的
            //   自己也取消掉；
            // - 周期兜底任务续排必须 REPLACE：APPEND_OR_REPLACE 会把新任务
            //   追加到同一条边界链上——链上每个任务执行完又各自续排一个
            //   后继，周期任务每 15 分钟再追加一条，边界上的任务数按代
            //   指数增长（约 2^小时），一天就能堆出数十万条空转任务。
            //   REPLACE 会清掉重复的边界任务、只留一条（周期任务与边界链
            //   是不同 unique 名，不会取消自己；若边界任务恰在运行会被
            //   停掉，其 finally 仍会自愈补排一条）。
            TimedWallpaperScheduler.scheduleNext(applicationContext, append = isBoundary)
        }
    }

    private fun runOnce(): Result {
        val context = applicationContext
        val active = ActiveWallpaperStore.load(context) ?: return Result.success()
        val parentDir = active.timedParentDir ?: return Result.success()

        val parent = File(parentDir)
        val charging = BatteryGuard.isCharging(context)
        val slot = TimedScheduleResolver.resolveForPackage(parent, Calendar.getInstance(), charging)
            ?: return Result.success()

        if (slot.id == active.id && slot.dir.absolutePath == active.dir) {
            return Result.success() // 已是当前时段
        }

        // minIntervalMinutes 节流（monotonic 时钟，不怕用户改系统时间）。
        // 注意 elapsedRealtime 在重启后归零：上次开机残留的时间戳会让差值变成
        // 负数——若不处理，负数永远小于节流窗口，重启后 timed 切换会被阻塞
        // 直到 elapsedRealtime 追平旧值（可能长达数天）。负差值视为“新开机，
        // 允许立即切换”。
        val schedule = runCatching {
            TimedScheduleResolver.parseSchedule(File(parent, "content/schedule.json").readText())
        }.getOrNull()
        val minInterval = schedule?.minIntervalMinutes ?: 0
        if (minInterval > 0) {
            val elapsed = SystemClock.elapsedRealtime() - ActiveWallpaperStore.timedLastSwitch(context)
            if (elapsed in 0 until minInterval * 60_000L) return Result.success()
        }

        // 竞态防护：从开头的 load 到这里的 save 隔着文件 IO（解析 schedule +
        // slot manifest），用户可能恰好在这段窗口里应用了别的壁纸。save 前
        // 重读激活记录，若已不再是本 timed 包（timedParentDir 变了或为空），
        // 放弃本次切换——否则旧 slot 记录会把用户新选的壁纸顶掉。
        val latest = ActiveWallpaperStore.load(context)
        if (latest == null || latest.timedParentDir != parentDir) {
            return Result.success()
        }

        ActiveWallpaperStore.save(
            context,
            ActiveWallpaper(
                id = slot.id,
                type = slot.type,
                dir = slot.dir.absolutePath,
                entry = slot.entry,
                // slot 共享父包的用户配置（apply 时持久化）；缺失（老版本升级 /
                // 未显式 apply 过）才落到默认参数。此前固定写 "{}" 会把用户调好的
                // 参数在每次时段切换时清掉。
                configJson = ActiveWallpaperStore.timedParentConfig(context) ?: "{}",
                capabilitiesJson = slot.capabilitiesJson,
                timedParentDir = parentDir,
            ),
        )
        ActiveWallpaperStore.setTimedLastSwitch(context, SystemClock.elapsedRealtime())
        // Engine 与 Worker 同进程：直接热切换，无需重新走系统应用流程。
        ConfigBus.emit(ConfigBus.Event.WALLPAPER_CHANGED)
        return Result.success()
    }
}

object TimedWallpaperScheduler {

    private const val WORK_NAME = "zuno_timed_switch"
    private const val BOUNDARY_WORK_NAME = "zuno_timed_boundary"

    /** 边界一次性任务的标记：doWork 据此选择续排策略（见 doWork 注释）。 */
    internal const val KEY_BOUNDARY = "boundary"

    /**
     * 幂等注册周期任务。
     * KEEP：每次 App 启动不重置周期起点（UPDATE 会刷新计时，导致节奏漂移）。
     * 15 分钟为平台允许的最小周期。
     */
    fun ensureScheduled(context: Context) {
        val request = PeriodicWorkRequestBuilder<TimedWallpaperWorker>(15, TimeUnit.MINUTES)
            .build()
        WorkManager.getInstance(context).enqueueUniquePeriodicWork(
            WORK_NAME,
            ExistingPeriodicWorkPolicy.KEEP,
            request,
        )
        scheduleNext(context)
    }

    /**
     * 在下一个规则边界排一个一次性任务，弥补 15 分钟周期粒度。
     *
     * 只有当前激活的是 timed 包时才排；切换到普通壁纸后取消旧任务。
     * WorkManager 的 initialDelay 仍可能被 Doze 推迟，所以周期任务不能删。
     */
    fun scheduleNext(context: Context, append: Boolean = false) {
        val active = ActiveWallpaperStore.load(context)
        val parentDir = active?.timedParentDir
        if (parentDir == null) {
            WorkManager.getInstance(context).cancelUniqueWork(BOUNDARY_WORK_NAME)
            return
        }
        val delay = TimedScheduleResolver.nextTransitionDelayMillis(
            File(parentDir),
            Calendar.getInstance(),
            BatteryGuard.isCharging(context),
        )
        if (delay == null) {
            WorkManager.getInstance(context).cancelUniqueWork(BOUNDARY_WORK_NAME)
            return
        }
        val request = OneTimeWorkRequestBuilder<TimedWallpaperWorker>()
            .setInitialDelay(delay, TimeUnit.MILLISECONDS)
            .setInputData(workDataOf(KEY_BOUNDARY to true))
            .build()
        // 从正在运行的 boundary worker 内部续排时用 APPEND_OR_REPLACE：
        // REPLACE 会取消自己；APPEND 把新任务挂到当前链之后，不会自取消。
        // App 启动/切换壁纸时用 REPLACE，避免重复启动叠加多条延迟任务。
        WorkManager.getInstance(context).enqueueUniqueWork(
            BOUNDARY_WORK_NAME,
            if (append) ExistingWorkPolicy.APPEND_OR_REPLACE else ExistingWorkPolicy.REPLACE,
            request,
        )
    }
}
