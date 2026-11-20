package com.zuno.wallpaper.wallpaper.html

import android.webkit.MimeTypeMap

/**
 * 本地资源 MIME 推断。
 * MimeTypeMap 在部分 ROM 上对 js/woff2 等返回 null（会导致 WebView 拒绝执行），
 * 因此常见扩展名走内置表，其余回落系统表。
 */
object MimeTypes {

    private val EXPLICIT = mapOf(
        "html" to ("text/html" to "utf-8"),
        "htm" to ("text/html" to "utf-8"),
        "css" to ("text/css" to "utf-8"),
        "js" to ("text/javascript" to "utf-8"),
        "mjs" to ("text/javascript" to "utf-8"),
        "json" to ("application/json" to "utf-8"),
        "svg" to ("image/svg+xml" to null),
        "png" to ("image/png" to null),
        "jpg" to ("image/jpeg" to null),
        "jpeg" to ("image/jpeg" to null),
        "gif" to ("image/gif" to null),
        "webp" to ("image/webp" to null),
        "avif" to ("image/avif" to null),
        "mp4" to ("video/mp4" to null),
        "webm" to ("video/webm" to null),
        "mp3" to ("audio/mpeg" to null),
        "woff" to ("font/woff" to null),
        "woff2" to ("font/woff2" to null),
        "ttf" to ("font/ttf" to null),
        "otf" to ("font/otf" to null),
    )

    data class Type(val type: String, val charset: String?)

    fun forFileName(name: String): Type {
        val ext = name.substringAfterLast('.', "").lowercase()
        EXPLICIT[ext]?.let { (t, c) -> return Type(t, c) }
        val sys = MimeTypeMap.getSingleton().getMimeTypeFromExtension(ext)
        return if (sys != null) {
            Type(sys, if (sys.startsWith("text/")) "utf-8" else null)
        } else {
            // application/octet-stream：字体等未知类型仍可下载，但不会被当作脚本执行。
            Type("application/octet-stream", null)
        }
    }
}
