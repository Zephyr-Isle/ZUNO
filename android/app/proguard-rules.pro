# ZUNO R8 规则。
# Flutter / 插件自带 consumer rules；这里只补 ZUNO 自身代码的反射触点。

# addJavascriptInterface：WebView 通过注解反射调用桥方法，
# shrink 后若方法被移除/改名，页面调用会静默失败。
-keepclassmembers class com.zuno.wallpaper.wallpaper.html.WallpaperJsBridge {
    @android.webkit.JavascriptInterface <methods>;
}

# WorkManager 通过反射实例化 Worker（类引用来自 PeriodicWorkRequestBuilder 的
# class token，理论上已保留；显式声明构造器兜底）。
-keep class com.zuno.wallpaper.wallpaper.timed.TimedWallpaperWorker {
    <init>(android.content.Context, androidx.work.WorkerParameters);
}

# WorkManager 内置的 Room 数据库（WorkDatabase + 生成的 *_Impl）在初始化时用
# Class.getCanonicalName() 反射拼接实现类名。AGP 9.1 的 R8 全模式优化会破坏
# 这条调用链（真机 release 验证：InitializationProvider 阶段崩溃，报
# "Failed to create an instance of class androidx.work.impl.WorkDatabase.canonicalName"）。
# 整包保留 work.impl（代价 ~1MB），换 release 稳定性。
-keep class androidx.work.impl.** { *; }

# 壁纸服务由系统按 manifest 里的类名实例化（AAPT 默认规则已覆盖，显式兜底）。
-keep class com.zuno.wallpaper.wallpaper.ZunoWallpaperService { *; }
-keep class com.zuno.wallpaper.wallpaper.html.HtmlPreviewActivity { *; }
