package com.zuno.wallpaper.bridge

import android.content.Context
import android.content.SharedPreferences

/**
 * 账号会话的本机存储（应用私有目录）。
 *
 * 为什么不复用 `zuno_config`：那份文件是壁纸运行时的事实来源，被
 * WallpaperService 的每次热切换读取；账号 token 与壁纸渲染无关，
 * 混进去只会让“读配置”这条最热的路径多带一份无关数据。
 *
 * 为什么不用 EncryptedSharedPreferences：会引入 androidx.security 依赖，
 * 而这个 token 只在本进程内用于设置 HTTP Authorization 头，不落日志、
 * 不进 WebView。应用私有目录已满足“其它 App 不可读”的等价安全级别。
 * 真要更强的隔离，后续换 Keystore 包装即可，接口不变。
 */
object AuthStore {

    private const val PREFS_NAME = "zuno_auth"
    private const val KEY_TOKEN = "auth.token"
    private const val KEY_USER_ID = "auth.user_id"
    private const val KEY_EMAIL = "auth.email"
    private const val KEY_EXPIRES_AT = "auth.expires_at"

    private fun prefs(context: Context): SharedPreferences =
        context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)

    /** 读取会话；没有 token 返回 null（等同未登录）。 */
    fun load(context: Context): Map<String, Any?>? {
        val prefs = prefs(context)
        val token = prefs.getString(KEY_TOKEN, null)
        if (token.isNullOrEmpty()) return null
        return mapOf(
            "token" to token,
            "userId" to prefs.getString(KEY_USER_ID, null),
            "email" to prefs.getString(KEY_EMAIL, null),
            "expiresAt" to prefs.getLong(KEY_EXPIRES_AT, 0L),
        )
    }

    fun save(context: Context, token: String, userId: String?, email: String?, expiresAt: Long) {
        prefs(context).edit()
            .putString(KEY_TOKEN, token)
            .putString(KEY_USER_ID, userId)
            .putString(KEY_EMAIL, email)
            .putLong(KEY_EXPIRES_AT, expiresAt)
            .apply()
    }

    fun clear(context: Context) {
        prefs(context).edit()
            .remove(KEY_TOKEN)
            .remove(KEY_USER_ID)
            .remove(KEY_EMAIL)
            .remove(KEY_EXPIRES_AT)
            .apply()
    }
}
