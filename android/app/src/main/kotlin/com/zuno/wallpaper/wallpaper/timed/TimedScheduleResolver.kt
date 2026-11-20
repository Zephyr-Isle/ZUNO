package com.zuno.wallpaper.wallpaper.timed

import android.util.Log
import org.json.JSONArray
import org.json.JSONObject
import java.io.File
import java.util.Calendar

/**
 * timed 壁纸的调度解析。
 *
 * timed 不是渲染类型：它只是一个“元调度器”数据结构（schedule.json 描述哪些时段用哪个
 * slot 子壁纸）。真正的切换由 TimedWallpaperWorker（WorkManager 周期任务）执行：
 * 解析 → 选 slot → 更新 SharedPreferences → ConfigBus 通知 Engine 热切换。
 *
 * 为什么不用 AlarmManager 做高频切换：Doze 模式会压制高频 alarm 且更耗电；
 * WorkManager 周期任务（>= 15 分钟，平台硬限制）由系统合并调度，代价最低。
 */
object TimedScheduleResolver {

    data class Slot(
        /** slot 子包 manifest.json 里的 id。 */
        val id: String,
        /** slot 目录绝对路径（<parent>/content/<slotName>）。 */
        val dir: File,
        /** slot 的渲染类型：video / html / depth（不允许嵌套 timed）。 */
        val type: String,
        /** slot 入口相对 slot 目录的路径。 */
        val entry: String,
        val capabilitiesJson: String,
        val title: String,
    )

    data class Schedule(
        /** minutesOfDay: [from, to) 窗口；from > to 表示跨午夜。 */
        val rules: List<Triple<Int, Int, String>>,
        val defaultSlot: String,
        val chargingOnly: Boolean,
        val minIntervalMinutes: Int,
    )

    // ---------- schedule.json ----------

    fun parseSchedule(json: String): Schedule {
        val root = JSONObject(json)
        val rulesJson = root.optJSONArray("rules") ?: JSONArray()
        val rules = ArrayList<Triple<Int, Int, String>>()
        for (i in 0 until rulesJson.length()) {
            val rule = rulesJson.getJSONObject(i)
            val from = parseHhMm(rule.getString("from"))
            val to = parseHhMm(rule.getString("to"))
            val wallpaper = rule.getString("wallpaper")
            rules.add(Triple(from, to, wallpaper))
        }
        val constraints = root.optJSONObject("constraints") ?: JSONObject()
        return Schedule(
            rules = rules,
            defaultSlot = root.optString("default", ""),
            chargingOnly = constraints.optBoolean("chargingOnly", false),
            minIntervalMinutes = constraints.optInt("minIntervalMinutes", 0),
        )
    }

    /** "HH:mm" → 当日分钟数；非法格式抛 IllegalArgumentException（导入期已校验，运行期防御）。 */
    private fun parseHhMm(raw: String): Int {
        val parts = raw.split(":")
        if (parts.size != 2) throw IllegalArgumentException("bad time: $raw")
        val h = parts[0].trim().toInt()
        val m = parts[1].trim().toInt()
        require(h in 0..23 && m in 0..59) { "bad time: $raw" }
        return h * 60 + m
    }

    /**
     * 纯函数：给定 schedule、当前时间与充电状态，返回应激活的 slot 目录名。
     * 规则匹配：from <= to 时 [from, to)；from > to（跨午夜）时 m >= from || m < to；
     * from == to 视为空窗口（永不匹配），落入 default。
     * chargingOnly 且未充电 → 返回 null（保持现状，不切换）。
     */
    fun resolveSlotName(schedule: Schedule, now: Calendar, charging: Boolean): String? {
        if (schedule.chargingOnly && !charging) return null
        val minutes = now.get(Calendar.HOUR_OF_DAY) * 60 + now.get(Calendar.MINUTE)
        for ((from, to, slot) in schedule.rules) {
            val matches = if (from < to) {
                minutes in from until to
            } else if (from > to) {
                minutes >= from || minutes < to
            } else {
                false
            }
            if (matches) return slot
        }
        return schedule.defaultSlot.ifEmpty { null }
    }

    /**
     * 距离下一个“规则边界”的毫秒数（from/to 都是切换点）。
     *
     * WorkManager 周期任务最小 15 分钟，若只在周期点检查，整点切换最多会晚
     * 15 分钟。这里算出最近边界，交给一次性任务在边界附近唤醒；周期任务继续
     * 作为兜底（Doze/重启后一次性任务丢失时仍能恢复）。
     *
     * 返回 null：没有规则、只有默认时段，或 chargingOnly 且当前未充电
     * （充电状态变化没有固定时刻，交给周期任务）。
     */
    fun nextTransitionDelayMillis(packageDir: File, now: Calendar, charging: Boolean): Long? {
        val schedule = try {
            val file = File(packageDir, "content/schedule.json")
            if (!file.isFile) return null
            parseSchedule(file.readText())
        } catch (t: Throwable) {
            Log.w("ZunoTimed", "next boundary parse failed: ${t.message}")
            return null
        }
        if (schedule.chargingOnly && !charging) return null
        if (schedule.rules.isEmpty()) return null

        val nowMs = now.timeInMillis
        var best: Long? = null
        for ((from, to, _) in schedule.rules) {
            // from == to 是空窗口，永远不会命中，也不构成有效切换点。
            if (from == to) continue
            for (minute in intArrayOf(from, to)) {
                val candidate = Calendar.getInstance().apply {
                    timeInMillis = nowMs
                    set(Calendar.HOUR_OF_DAY, minute / 60)
                    set(Calendar.MINUTE, minute % 60)
                    set(Calendar.SECOND, 0)
                    set(Calendar.MILLISECOND, 0)
                }
                if (candidate.timeInMillis <= nowMs) {
                    candidate.add(Calendar.DAY_OF_YEAR, 1)
                }
                val delay = candidate.timeInMillis - nowMs
                if (delay > 0 && (best == null || delay < best!!)) best = delay
            }
        }
        // 至少留 5 秒，避免刚好落在边界上时一次性任务立即触发、空转一次。
        return best?.coerceAtLeast(5_000L)
    }

    // ---------- 包级入口 ----------

    /**
     * 解析 timed 包当前应激活的 slot（含 slot 子包 manifest 信息）。
     * 任何一步失败返回 null（保持当前激活状态）。
     */
    fun resolveForPackage(packageDir: File, now: Calendar, charging: Boolean): Slot? {
        try {
            val scheduleFile = File(packageDir, "content/schedule.json")
            if (!scheduleFile.isFile) return null
            val schedule = parseSchedule(scheduleFile.readText())
            val slotName = resolveSlotName(schedule, now, charging) ?: return null
            return readSlot(File(packageDir, "content/$slotName"))
        } catch (t: Throwable) {
            Log.w("ZunoTimed", "resolve failed: ${t.message}")
            return null
        }
    }

    /**
     * 读取 slot 子包的 manifest（导入时已校验最简字段，这里只读运行必需项）。
     */
    fun readSlot(slotDir: File): Slot? {
        try {
            val manifest = File(slotDir, "manifest.json")
            if (!manifest.isFile) return null
            val json = JSONObject(manifest.readText())
            val type = json.optString("type", "")
            val entry = json.optString("entry", "")
            if (type !in setOf("video", "html", "depth") || entry.isEmpty()) return null
            val entryFile = File(slotDir, entry)
            if (!entryFile.isFile) return null
            return Slot(
                id = json.optString("id", slotDir.name),
                dir = slotDir,
                type = type,
                entry = entry,
                capabilitiesJson = json.optJSONObject("capabilities")?.toString() ?: "{}",
                title = json.optString("title", slotDir.name),
            )
        } catch (t: Throwable) {
            Log.w("ZunoTimed", "readSlot failed: ${t.message}")
            return null
        }
    }
}
