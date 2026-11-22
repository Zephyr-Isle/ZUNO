package com.zuno.wallpaper.wallpaper

import android.content.Context
import android.content.SharedPreferences
import org.json.JSONObject

/**
 * “当前激活壁纸”的唯一事实来源（Single Source of Truth）。
 *
 * 为什么用 SharedPreferences 而不是数据库：
 * - 写入方只有两个：Dart 侧“应用壁纸”（经 Platform Channel）、timed Worker 切换时段；
 * - 读取方是 WallpaperService.Engine（每次 onVisibilityChanged / 热切换都会读），
 *   SharedPreferences 是进程内内存缓存 + 异步落盘，读取零开销；
 * - 规格允许 “SharedPreferences 或 MMKV”，MMKV 需要额外 so 且单写入方场景收益有限。
 *
 * 注意：这里存的是“激活的渲染单元”。timed 类型的包本身不渲染，
 * 激活的是其某个 slot 子壁纸，timedParentDir 记录父包根目录，
 * 供 TimedWallpaperWorker 周期性重新解析 schedule.json。
 */
data class ActiveWallpaper(
    /** 激活渲染单元的 id（timed 时为 slot 子包的 id）。 */
    val id: String,
    /** video | html | depth（timed 不会出现在这里）。 */
    val type: String,
    /** 渲染单元的包根目录绝对路径（timed 时为 slot 目录，如 <parent>/content/slot_day）。 */
    val dir: String,
    /** 入口文件相对 [dir] 的路径，如 content/main.mp4。 */
    val entry: String,
    /** 用户可调参数 JSON 对象，如 {"playback_speed":1.5}。 */
    val configJson: String,
    /** capabilities JSON（HTML 的 pointer、depth 的 sensors 等）。 */
    val capabilitiesJson: String,
    /** 若来自 timed 包，为父包根目录绝对路径；否则 null。 */
    val timedParentDir: String?,
)

object ActiveWallpaperStore {

    private const val PREFS_NAME = "zuno_config"

    private const val KEY_ID = "active.id"
    private const val KEY_TYPE = "active.type"
    private const val KEY_DIR = "active.dir"
    private const val KEY_ENTRY = "active.entry"
    private const val KEY_CONFIG = "active.config"
    private const val KEY_CAPABILITIES = "active.capabilities"
    private const val KEY_TIMED_PARENT = "active.timed_parent"
    private const val KEY_PERF_TIER = "perf.tier"
    private const val KEY_TIMED_LAST_SWITCH = "timed.last_switch"
    private const val KEY_THEME_MODE = "app.theme_mode"

    /** 壁纸库后端地址；ZUNO 不内置云端服务，地址由用户在设置页填写。 */
    private const val KEY_LIBRARY_URL = "library.base_url"

    /** 主界面底部玻璃 TAB 是否显示（默认隐藏，顶栏按钮提供页面切换入口）。 */
    private const val KEY_SHOW_TAB_BAR = "app.show_tab_bar"

    /** 视频解码方式：auto | hardware | software（默认 auto = 硬件优先）。 */
    private const val KEY_VIDEO_DECODE_MODE = "video.decode_mode"

    /** 解码失败时是否在 App 内提示切换到软解（默认 true）。 */
    private const val KEY_VIDEO_DECODE_PROMPT = "video.decode_prompt"

    /** 最近一次视频解码失败的信息（JSON：entryId/message/at），成功后清除。 */
    private const val KEY_VIDEO_DECODE_ERROR = "video.decode_error"

    /** 深度视差的全局强度倍率（0.6 / 1.0 / 1.4），乘以包内 parallax_strength。 */
    private const val KEY_DEPTH_STRENGTH_SCALE = "depth.strength_scale"

    /**
     * timed 父包的用户配置（apply 时写入）。
     * Worker 切换 slot 与预览滑杆激活 slot 时复用它——slot 子包共享父包参数；
     * 没有这份持久化，任何 slot 切换都会把激活记录的 config 覆盖成 "{}"，
     * 用户在详情页调好的参数（音量/速度/强度等）全部丢失。
     */
    private const val KEY_TIMED_PARENT_CONFIG = "timed.parent_config"

    fun prefs(context: Context): SharedPreferences =
        context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)

    fun load(context: Context): ActiveWallpaper? {
        val p = prefs(context)
        val id = p.getString(KEY_ID, null) ?: return null
        return ActiveWallpaper(
            id = id,
            type = p.getString(KEY_TYPE, null) ?: return null,
            dir = p.getString(KEY_DIR, null) ?: return null,
            entry = p.getString(KEY_ENTRY, null) ?: return null,
            configJson = p.getString(KEY_CONFIG, "{}") ?: "{}",
            capabilitiesJson = p.getString(KEY_CAPABILITIES, "{}") ?: "{}",
            timedParentDir = p.getString(KEY_TIMED_PARENT, null),
        )
    }

    fun save(context: Context, wallpaper: ActiveWallpaper) {
        prefs(context).edit()
            .putString(KEY_ID, wallpaper.id)
            .putString(KEY_TYPE, wallpaper.type)
            .putString(KEY_DIR, wallpaper.dir)
            .putString(KEY_ENTRY, wallpaper.entry)
            .putString(KEY_CONFIG, wallpaper.configJson)
            .putString(KEY_CAPABILITIES, wallpaper.capabilitiesJson)
            .putString(KEY_TIMED_PARENT, wallpaper.timedParentDir)
            .apply()
    }

    /** 仅更新用户可调参数（HTML 壁纸的 JS 桥会高频调用，不能整体 save 造成竞态覆盖 dir 等字段）。 */
    fun updateConfig(context: Context, configJson: String) {
        prefs(context).edit().putString(KEY_CONFIG, configJson).apply()
    }

    fun setPerformanceTier(context: Context, tier: String) {
        prefs(context).edit().putString(KEY_PERF_TIER, tier).apply()
    }

    fun performanceTier(context: Context): String =
        prefs(context).getString(KEY_PERF_TIER, null) ?: "medium"

    /** 应用外观：system | light | dark（默认跟随系统）。 */
    fun setThemeMode(context: Context, mode: String) {
        prefs(context).edit().putString(KEY_THEME_MODE, mode).apply()
    }

    fun themeMode(context: Context): String =
        prefs(context).getString(KEY_THEME_MODE, null) ?: "system"

    /** 壁纸库地址；返回 null 表示用户没设置过（用编译期默认值）。 */
    fun libraryUrl(context: Context): String? =
        prefs(context).getString(KEY_LIBRARY_URL, null)

    fun setLibraryUrl(context: Context, url: String) {
        prefs(context).edit().putString(KEY_LIBRARY_URL, url).apply()
    }

    /** 底部玻璃 TAB 显隐；默认隐藏（顶栏按钮切换「我的壁纸 / 壁纸库」）。 */
    fun showTabBar(context: Context): Boolean =
        prefs(context).getBoolean(KEY_SHOW_TAB_BAR, false)

    fun setShowTabBar(context: Context, visible: Boolean) {
        prefs(context).edit().putBoolean(KEY_SHOW_TAB_BAR, visible).apply()
    }

    fun setTimedLastSwitch(context: Context, atMillis: Long) {
        prefs(context).edit().putLong(KEY_TIMED_LAST_SWITCH, atMillis).apply()
    }

    fun timedLastSwitch(context: Context): Long =
        prefs(context).getLong(KEY_TIMED_LAST_SWITCH, 0L)

    fun setTimedParentConfig(context: Context, configJson: String) {
        prefs(context).edit().putString(KEY_TIMED_PARENT_CONFIG, configJson).apply()
    }

    fun timedParentConfig(context: Context): String? =
        prefs(context).getString(KEY_TIMED_PARENT_CONFIG, null)

    // ---------- 视频解码 ----------

    fun videoDecodeMode(context: Context): String {
        val mode = prefs(context).getString(KEY_VIDEO_DECODE_MODE, "auto")
        return if (mode == "hardware" || mode == "software") mode else "auto"
    }

    fun setVideoDecodeMode(context: Context, mode: String) {
        val normalized = if (mode == "hardware" || mode == "software") mode else "auto"
        prefs(context).edit().putString(KEY_VIDEO_DECODE_MODE, normalized).apply()
    }

    fun videoDecodePromptEnabled(context: Context): Boolean =
        prefs(context).getBoolean(KEY_VIDEO_DECODE_PROMPT, true)

    fun setVideoDecodePromptEnabled(context: Context, enabled: Boolean) {
        prefs(context).edit().putBoolean(KEY_VIDEO_DECODE_PROMPT, enabled).apply()
    }

    /** 记录失败供 Flutter 端下次回到前台时提示；entryId 用于过滤已切换壁纸的旧错误。 */
    fun recordVideoDecodeFailure(context: Context, entryId: String, message: String) {
        val json = JSONObject()
            .put("entryId", entryId)
            .put("message", message)
            .put("at", System.currentTimeMillis())
        prefs(context).edit().putString(KEY_VIDEO_DECODE_ERROR, json.toString()).apply()
    }

    fun clearVideoDecodeFailure(context: Context) {
        prefs(context).edit().remove(KEY_VIDEO_DECODE_ERROR).apply()
    }

    /** 返回失败信息；未开启提示或没有失败时返回 null。 */
    fun videoDecodeFailure(context: Context): Map<String, Any>? {
        if (!videoDecodePromptEnabled(context)) return null
        val raw = prefs(context).getString(KEY_VIDEO_DECODE_ERROR, null) ?: return null
        val json = runCatching { JSONObject(raw) }.getOrNull() ?: return null
        return mapOf(
            "entryId" to json.optString("entryId", ""),
            "message" to json.optString("message", ""),
            "at" to json.optLong("at", 0L),
            "mode" to videoDecodeMode(context),
        )
    }

    // ---------- 深度视差 ----------

    fun depthStrengthScale(context: Context): Float =
        prefs(context).getFloat(KEY_DEPTH_STRENGTH_SCALE, 1.0f).coerceIn(0.4f, 2.0f)

    fun setDepthStrengthScale(context: Context, scale: Float) {
        prefs(context).edit()
            .putFloat(KEY_DEPTH_STRENGTH_SCALE, scale.coerceIn(0.4f, 2.0f))
            .apply()
    }
}
