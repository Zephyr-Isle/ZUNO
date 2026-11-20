package com.zuno.wallpaper.wallpaper.html

import android.webkit.JavascriptInterface

/**
 * 暴露给 HTML 壁纸的 JS 桥。
 *
 * 安全边界（规格要求“最小化，只允许 setConfig(key, value) 这类无副作用调用”）：
 * - 只有一个 @JavascriptInterface 方法，且只写回 config 存储，不触碰任何系统能力；
 * - addJavascriptInterface 仅在 API 17+ 生效（minSdk 24 满足），注入对象名为 window.ZunoWallpaper；
 * - 页面拿不到 Context、Intent、文件系统等任何引用。
 */
class WallpaperJsBridge(
    private val onSetConfig: (key: String, value: String) -> Unit,
) {

    /**
     * 页面调用示例：ZunoWallpaper.setConfig('speed', '1.5')
     * value 统一为字符串，由 Dart 管理端按 manifest.config 的类型定义解析。
     * 超长 value 直接丢弃：参数值都是短标量（数字/布尔/颜色），
     * 放行超大字符串等于给页面一个写爆 SharedPreferences 的原语。
     */
    @JavascriptInterface
    fun setConfig(key: String, value: String) {
        if (key.isBlank() || key.length > 128) return
        if (value.length > 4096) return
        onSetConfig(key, value)
    }
}
