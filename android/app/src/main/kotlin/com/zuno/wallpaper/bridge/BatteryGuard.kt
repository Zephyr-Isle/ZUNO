package com.zuno.wallpaper.bridge

import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.net.Uri
import android.os.BatteryManager
import android.os.PowerManager
import android.provider.Settings

/**
 * 电池优化 / 充电状态相关的工具。
 *
 * timed 壁纸依赖 WorkManager 周期任务。Doze 模式下周期任务会被延迟到维护窗口，
 * 加入电池优化白名单能显著降低切换延迟（spec：OEM 电池优化白名单引导）。
 */
object BatteryGuard {

    fun isIgnoringOptimizations(context: Context): Boolean {
        val pm = context.getSystemService(Context.POWER_SERVICE) as PowerManager
        return pm.isIgnoringBatteryOptimizations(context.packageName)
    }

    /**
     * 跳转系统“忽略电池优化”确认对话框。
     * 使用 ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS 直达确认框；
     * 若厂商 ROM 不支持则退化为打开常规设置页。
     */
    fun requestIgnoringOptimizations(context: Context): Boolean {
        return try {
            val intent = Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS)
                .setData(Uri.parse("package:${context.packageName}"))
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            context.startActivity(intent)
            true
        } catch (_: Exception) {
            try {
                val fallback = Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS)
                fallback.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                context.startActivity(fallback)
                true
            } catch (_: Exception) {
                false
            }
        }
    }

    /**
     * 当前是否在充电。
     * 只读 sticky broadcast ACTION_BATTERY_CHANGED：系统在每次电量/充电状态
     * 变化时都重发它，sticky 始终是最新快照；registerReceiver(null, filter)
     * 无需注册监听即可拿到，这是在 Worker 里查询充电状态的最低开销方式。
     *
     * 绝不能读 ACTION_CHARGING 的 sticky：它只在插拔充电线的状态切换瞬间发送
     * 一次，sticky 会一直保留那次的内容——拔线后读到的仍是插线时的旧 intent
     * （status=CHARGING），充电状态从此被永久误判为 true，timed 包的
     * chargingOnly 约束失效（未充电时照样切换）。
     */
    fun isCharging(context: Context): Boolean {
        val intent = context.registerReceiver(null, IntentFilter(Intent.ACTION_BATTERY_CHANGED))
            ?: return false
        val plugged = intent.getIntExtra(BatteryManager.EXTRA_PLUGGED, 0)
        // 只以 plugged 判断充电。status==FULL 不能算：不少 ROM 在拔线充满后
        // 仍上报 FULL——chargingOnly 的 timed 包会在无充电器时照常切换，
        // 正是本方法 KDoc 声明要避免的误报。
        return plugged > 0
    }
}
