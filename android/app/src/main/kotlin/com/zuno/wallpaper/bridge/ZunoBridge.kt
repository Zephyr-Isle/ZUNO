package com.zuno.wallpaper.bridge

import android.app.WallpaperInfo
import android.app.WallpaperManager
import android.content.ComponentName
import android.content.Intent
import android.os.Build
import com.zuno.wallpaper.MainActivity
import com.zuno.wallpaper.wallpaper.ActiveWallpaper
import com.zuno.wallpaper.wallpaper.ActiveWallpaperStore
import com.zuno.wallpaper.wallpaper.ConfigBus
import com.zuno.wallpaper.wallpaper.ZunoWallpaperService
import com.zuno.wallpaper.wallpaper.html.HtmlPreviewActivity
import com.zuno.wallpaper.wallpaper.timed.TimedScheduleResolver
import com.zuno.wallpaper.wallpaper.timed.TimedWallpaperScheduler
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.util.Calendar

/**
 * Dart 管理端 ↔ 原生 的唯一 Platform Channel（"zuno/native"）。
 *
 * 设计原则：
 * - “激活壁纸”的写入权归这里：Dart 把 (id/type/dir/entry/config/capabilities) 传过来，
 *   原生写入 SharedPreferences 并通过 ConfigBus 通知运行中的 Engine 热切换。
 * - 应用到系统走 WallpaperManager.ACTION_CHANGE_LIVE_WALLPAPER（带确认的系统预览页）。
 *   为什么不走 WallpaperManager.setWallpaperComponent()：该方法不在公共 SDK 中
 *   （需要系统签名权限 SET_WALLPAPER_COMPONENT），普通应用只能通过系统预览页让用户确认。
 */
object ZunoBridge {

    private const val CHANNEL = "zuno/native"

    fun register(activity: MainActivity, messenger: BinaryMessenger) {
        MethodChannel(messenger, CHANNEL).setMethodCallHandler { call, result ->
            try {
                handle(activity, call.method, call.arguments, result)
            } catch (t: Throwable) {
                result.error("native_error", "${t.javaClass.simpleName}: ${t.message}", null)
            }
        }
    }

    private fun handle(
        activity: MainActivity,
        method: String,
        arguments: Any?,
        result: MethodChannel.Result,
    ) {
        val args = arguments as? Map<*, *> ?: emptyMap<Any, Any>()
        when (method) {

            "deviceApiLevel" -> result.success(Build.VERSION.SDK_INT)

            "setActiveWallpaper" -> {
                // Dart 侧已完成 manifest 校验；这里只做参数落地。
                // timed 类型不会走到这里（Dart 会先 resolveTimedSlot 拿到具体 slot）。
                // configJson 是“数据不是代码”：它会被原样拼接进
                // window.__ZUNO_CONFIG__ = <json>; 的 JS 注入（HTML 壁纸/预览）。
                // 损坏的历史数据或异常写入者必须在此收敛为 "{}"，否则页面热更新
                // 静默失效，甚至可能被构造成任意 JS 在壁纸 WebView 里执行。
                val configJson = runCatching {
                    org.json.JSONObject(args.str("configJson") ?: "{}").toString()
                }.getOrDefault("{}")
                val wallpaper = ActiveWallpaper(
                    id = args.str("id") ?: return result.error("bad_args", "id required", null),
                    type = args.str("type") ?: return result.error("bad_args", "type required", null),
                    dir = args.str("dir") ?: return result.error("bad_args", "dir required", null),
                    entry = args.str("entry") ?: return result.error("bad_args", "entry required", null),
                    configJson = configJson,
                    capabilitiesJson = args.str("capabilitiesJson") ?: "{}",
                    timedParentDir = args.str("timedParentDir"),
                )
                ActiveWallpaperStore.save(activity, wallpaper)
                // 新应用壁纸：上一次解码失败的提示已失去上下文，直接清掉。
                ActiveWallpaperStore.clearVideoDecodeFailure(activity)
                // timed 包：用户配置单独持久化为“父包配置”。TimedWallpaperWorker 切换
                // slot 与预览滑杆激活 slot 时复用它，否则 slot 切换会把 config 覆盖成
                // "{}"，用户调好的参数全部丢失。
                if (wallpaper.timedParentDir != null) {
                    ActiveWallpaperStore.setTimedParentConfig(activity, wallpaper.configJson)
                }
                // timed 包：按下一个规则边界补排一次性任务（15 分钟周期粒度之外
                // 的优化）；切到普通壁纸会取消旧的 boundary 任务。
                TimedWallpaperScheduler.scheduleNext(activity)
                // 通知运行中的 Engine 热切换（若壁纸当前不可见，Engine 会在可见时读取新配置）。
                ConfigBus.emit(ConfigBus.Event.WALLPAPER_CHANGED)
                result.success(true)
            }

            "getActiveWallpaper" -> {
                val w = ActiveWallpaperStore.load(activity) ?: run {
                    result.success(null); return
                }
                result.success(
                    mapOf(
                        "id" to w.id,
                        "type" to w.type,
                        "dir" to w.dir,
                        "entry" to w.entry,
                        "configJson" to w.configJson,
                        "capabilitiesJson" to w.capabilitiesJson,
                        "timedParentDir" to w.timedParentDir,
                    ),
                )
            }

            "launchWallpaperPreview" -> {
                // 系统动态壁纸预览页：用户点击“设置壁纸”后才真正生效。
                // 这是普通应用设置动态壁纸的标准途径。
                // ROM 回退链（真机/模拟器实测发现）：
                //   1) ACTION_CHANGE_LIVE_WALLPAPER —— 标准带确认的预览页；
                //   2) ACTION_LIVE_WALLPAPER_CHOOSER —— 系统选择器的“动态壁纸”列表；
                //   3) ACTION_SET_WALLPAPER —— 系统壁纸选择页（用户再进“动态壁纸”），
                //      MuMu 等部分镜像上 1/2 均未注册，只有 3 可用。
                // 三个 Intent 的 extra 都必须传 ComponentName 类型。
                val componentName = ComponentName(activity, ZunoWallpaperService::class.java)
                val launched = runCatching {
                    activity.startActivity(
                        Intent(WallpaperManager.ACTION_CHANGE_LIVE_WALLPAPER)
                            .putExtra(WallpaperManager.EXTRA_LIVE_WALLPAPER_COMPONENT, componentName),
                    )
                }.isSuccess
                val viaChooser = if (!launched) {
                    runCatching {
                        activity.startActivity(
                            Intent(WallpaperManager.ACTION_LIVE_WALLPAPER_CHOOSER)
                                .putExtra(WallpaperManager.EXTRA_LIVE_WALLPAPER_COMPONENT, componentName),
                        )
                    }.isSuccess
                } else {
                    false
                }
                val viaSetAction = if (!launched && !viaChooser) {
                    runCatching {
                        activity.startActivity(Intent(Intent.ACTION_SET_WALLPAPER))
                    }.isSuccess
                } else {
                    false
                }
                result.success(launched || viaChooser || viaSetAction)
            }

            "isLiveWallpaperActive" -> {
                val wm = WallpaperManager.getInstance(activity)
                val expected = ZunoWallpaperService::class.java.name

                // manifest 用相对类名注册 service（".wallpaper.ZunoWallpaperService"），
                // WallpaperInfo.getServiceName() 返回的是未展开的原样字符串，需按
                // PackageParser 的规则展开后再与全限定名比较。
                fun isActive(info: WallpaperInfo?): Boolean {
                    val expanded = info?.serviceName?.let { cls ->
                        when {
                            cls.startsWith(".") -> info.packageName + cls
                            !cls.contains(".") -> "${info.packageName}.$cls"
                            else -> cls
                        }
                    } ?: return false
                    return info.packageName == activity.packageName && expanded == expected
                }

                // wallpaperInfo 在壁纸服务未连接（进程刚被 force-stop/重启的窗口期，
                // 系统还没重新绑定）时返回 null，即使系统记录的当前壁纸就是本包。
                // 这个窗口期由 Dart 侧延迟复查兜底（MainShellScreen._requestWallpaperRole）。
                val active = isActive(wm.wallpaperInfo)
                result.success(active)
            }

            "setPerformanceTier" -> {
                ActiveWallpaperStore.setPerformanceTier(activity, args.str("tier") ?: "medium")
                ConfigBus.emit(ConfigBus.Event.CONFIG_CHANGED)
                result.success(true)
            }

            "getPerformanceTier" -> result.success(ActiveWallpaperStore.performanceTier(activity))

            "setThemeMode" -> {
                // system | light | dark —— 只影响 Flutter 管理端外观，不影响壁纸渲染。
                ActiveWallpaperStore.setThemeMode(activity, args.str("mode") ?: "system")
                result.success(true)
            }

            "getThemeMode" -> result.success(ActiveWallpaperStore.themeMode(activity))

            "getVideoDecodeMode" ->
                result.success(ActiveWallpaperStore.videoDecodeMode(activity))

            "setVideoDecodeMode" -> {
                ActiveWallpaperStore.setVideoDecodeMode(
                    activity,
                    args.str("mode") ?: "auto",
                )
                // 用户主动切换解码方式：旧失败记录已不适用；运行中的视频引擎
                // 收到 CONFIG_CHANGED 后会自行按新模式重建播放器。
                ActiveWallpaperStore.clearVideoDecodeFailure(activity)
                ConfigBus.emit(ConfigBus.Event.CONFIG_CHANGED)
                result.success(true)
            }

            "getVideoDecodePrompt" ->
                result.success(ActiveWallpaperStore.videoDecodePromptEnabled(activity))

            "setVideoDecodePrompt" -> {
                ActiveWallpaperStore.setVideoDecodePromptEnabled(
                    activity,
                    args["enabled"] as? Boolean ?: true,
                )
                result.success(true)
            }

            "getVideoDecodeFailure" ->
                result.success(ActiveWallpaperStore.videoDecodeFailure(activity))

            "clearVideoDecodeFailure" -> {
                ActiveWallpaperStore.clearVideoDecodeFailure(activity)
                result.success(true)
            }

            "getDepthStrengthScale" ->
                result.success(ActiveWallpaperStore.depthStrengthScale(activity).toDouble())

            "setDepthStrengthScale" -> {
                ActiveWallpaperStore.setDepthStrengthScale(
                    activity,
                    (args["scale"] as? Number)?.toFloat() ?: 1.0f,
                )
                ConfigBus.emit(ConfigBus.Event.CONFIG_CHANGED)
                result.success(true)
            }

            "resolveTimedSlot" -> {
                val dir = args.str("dir")
                    ?: return result.error("bad_args", "dir required", null)
                // 可选模拟时刻（timed 预览滑杆）：缺省 = 设备当前时间。
                // 预览模式绕过充电约束（用户手动选择时段）。
                val hour = (args["hour"] as? Number)?.toInt()
                val minute = (args["minute"] as? Number)?.toInt()
                // resolveForPackage 读并解析 schedule.json + slot 的 manifest.json，
                // 是真实文件 IO——预览滑杆拖动时高频触发，慢存储上会卡主线程
                // （本进程同时承载壁纸服务与 Flutter UI）。与 probeVideo* 一样
                // 放后台线程，主线程只负责回包。
                Thread {
                    val cal = Calendar.getInstance()
                    if (hour != null && minute != null) {
                        cal.set(Calendar.HOUR_OF_DAY, hour)
                        cal.set(Calendar.MINUTE, minute)
                        cal.set(Calendar.SECOND, 0)
                    }
                    val charging = if (hour != null) true else BatteryGuard.isCharging(activity)
                    val slot = TimedScheduleResolver.resolveForPackage(
                        File(dir), cal, charging,
                    )
                    android.os.Handler(android.os.Looper.getMainLooper()).post {
                        runCatching {
                            if (slot == null) {
                                result.success(null)
                            } else {
                                result.success(
                                    mapOf(
                                        "slotId" to slot.id,
                                        // slot 目录短名（slot_day/slot_night）：UI 标签展示用。
                                        // slotId 是全限定包 id（com.x.y.slot_night），直接显示会溢出。
                                        "slotName" to slot.dir.name,
                                        "slotDir" to slot.dir.absolutePath,
                                        "type" to slot.type,
                                        "entry" to slot.entry,
                                        // 预览激活 slot 时沿用用户已应用的父包配置（缺失则用默认）。
                                        "configJson" to (ActiveWallpaperStore.timedParentConfig(activity) ?: "{}"),
                                        "capabilitiesJson" to slot.capabilitiesJson,
                                    ),
                                )
                            }
                        }
                    }
                }.start()
            }

            "openHtmlPreview" -> {
                val dir = args.str("dir")
                    ?: return result.error("bad_args", "dir required", null)
                val entry = args.str("entry")
                    ?: return result.error("bad_args", "entry required", null)
                activity.startActivity(
                    HtmlPreviewActivity.intent(
                        activity,
                        dir,
                        entry,
                        args.str("configJson") ?: "{}",
                    ),
                )
                result.success(true)
            }

            "isIgnoringBatteryOptimizations" ->
                result.success(BatteryGuard.isIgnoringOptimizations(activity))

            "requestIgnoreBatteryOptimizations" ->
                result.success(BatteryGuard.requestIgnoringOptimizations(activity))

            "ensureThumbnail" -> {
                val dir = args.str("dir")
                    ?: return result.error("bad_args", "dir required", null)
                val type = args.str("type")
                    ?: return result.error("bad_args", "type required", null)
                val entry = args.str("entry")
                    ?: return result.error("bad_args", "entry required", null)
                val outPath = args.str("outPath")
                    ?: return result.error("bad_args", "outPath required", null)
                // 解码/取帧是毫秒到百毫秒级操作，放后台线程避免卡主线程；
                // MethodChannel.Result 必须在主线程应答，故 post 回主线程。
                // 线程可能比 FlutterEngine 活得久（用户立刻退出 App）：应答时
                // messenger 可能已销毁，runCatching 防止二次崩溃。
                Thread {
                    val path = ThumbnailGenerator.ensure(dir, type, entry, outPath)
                    android.os.Handler(android.os.Looper.getMainLooper()).post {
                        runCatching { result.success(path) }
                    }
                }.start()
            }

            "ensureHtmlThumbnail" -> {
                val dir = args.str("dir")
                    ?: return result.error("bad_args", "dir required", null)
                val entry = args.str("entry")
                    ?: return result.error("bad_args", "entry required", null)
                val outPath = args.str("outPath")
                    ?: return result.error("bad_args", "outPath required", null)
                // 离屏渲染在主线程异步执行（WebView 约束）；结果 post 回主线程应答，
                // runCatching 防 FlutterEngine 已销毁时的二次崩溃（同 ensureThumbnail）。
                com.zuno.wallpaper.wallpaper.html.HtmlThumbnailRenderer.render(
                    activity,
                    java.io.File(dir),
                    entry,
                    outPath,
                ) { path ->
                    android.os.Handler(android.os.Looper.getMainLooper()).post {
                        runCatching { result.success(path) }
                    }
                }
            }

            "probeVideoCodec" -> {
                val path = args.str("path")
                    ?: return result.error("bad_args", "path required", null)
                // MediaExtractor.setDataSource 是真实的 IO + demuxer 探测，
                // 大文件/损坏文件可到数百毫秒——与 probeVideoSupported 一样
                // 放后台线程，避免主线程卡帧乃至 ANR。
                Thread {
                    val mime = ThumbnailGenerator.probeVideoMime(path)
                    android.os.Handler(android.os.Looper.getMainLooper()).post {
                        runCatching { result.success(mime) }
                    }
                }.start()
            }

            "probeVideoSupported" -> {
                // 本机解码器能否实时解码该视频（profile/分辨率/帧率组合判定）。
                val path = args.str("path")
                    ?: return result.error("bad_args", "path required", null)
                Thread {
                    val supported = ThumbnailGenerator.probeVideoSupported(path)
                    android.os.Handler(android.os.Looper.getMainLooper()).post {
                        runCatching { result.success(supported) }
                    }
                }.start()
            }

            "sharePackage" -> {
                // 导出分享：文件由 Dart 侧流式打包到 cache/exports/，这里经
                // FileProvider 临时授权 + ACTION_SEND 拉起系统分享面板。
                val path = args.str("path")
                    ?: return result.error("bad_args", "path required", null)
                val title = args.str("title") ?: "ZUNO wallpaper"
                val file = java.io.File(path)
                if (!file.isFile) {
                    return result.error("bad_args", "exported file missing: $path", null)
                }
                val uri = androidx.core.content.FileProvider.getUriForFile(
                    activity,
                    "${activity.packageName}.fileprovider",
                    file,
                )
                val intent = Intent(Intent.ACTION_SEND).apply {
                    type = "application/zip"
                    putExtra(Intent.EXTRA_STREAM, uri)
                    addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                }
                result.success(runCatching {
                    activity.startActivity(Intent.createChooser(intent, title))
                }.isSuccess)
            }

            // ---------------------------------------------------------- 壁纸库地址
            "getLibraryUrl" -> result.success(ActiveWallpaperStore.libraryUrl(activity))

            "setLibraryUrl" -> {
                ActiveWallpaperStore.setLibraryUrl(activity, args.str("url") ?: "")
                result.success(true)
            }

            // ---------------------------------------------------------- 界面设置
            "getShowTabBar" ->
                result.success(ActiveWallpaperStore.showTabBar(activity))

            "setShowTabBar" -> {
                ActiveWallpaperStore.setShowTabBar(
                    activity,
                    args["visible"] as? Boolean ?: false,
                )
                result.success(true)
            }

            // ---------------------------------------------------------- 账号会话
            //
            // token 只做“本地记住登录态”：Dart 侧用完即从内存取出设 HTTP 头，
            // 原生不读它、不用于任何渲染路径。
            "authLoad" -> result.success(AuthStore.load(activity))

            "authSave" -> {
                val token = args.str("token")
                    ?: return result.error("bad_args", "token required", null)
                AuthStore.save(
                    activity,
                    token,
                    args.str("userId"),
                    args.str("email"),
                    (args["expiresAt"] as? Number)?.toLong() ?: 0L,
                )
                result.success(true)
            }

            "authClear" -> {
                AuthStore.clear(activity)
                result.success(true)
            }

            else -> result.notImplemented()
        }
    }

    private fun Map<*, *>.str(key: String): String? = this[key] as? String
}
