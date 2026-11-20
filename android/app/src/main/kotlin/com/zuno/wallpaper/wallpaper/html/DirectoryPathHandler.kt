package com.zuno.wallpaper.wallpaper.html

import android.net.Uri
import android.util.Log
import android.webkit.WebResourceResponse
import androidx.webkit.WebViewAssetLoader
import java.io.File
import java.io.FileInputStream
import java.io.FileNotFoundException

/**
 * 把包根目录（含 content/）以 https://appassets.local/ 提供。
 *
 * 为什么不用 file://：规格要求 HTML 壁纸运行在沙箱中——file:// 允许页面同源读取
 * 整个应用私有目录（allowFileAccessFromFileURLs 打开后甚至可以 XHR 任意文件），
 * 而 WebViewAssetLoader 给页面一个独立的 https 源，JS 的同源策略从此只约束包内资源。
 *
 * 安全要点：
 * - 所有请求路径做 canonical path 校验，杜绝 ../ 路径遍历逃出包目录；
 * - 只有真实存在的普通文件才会被返回，其余一律 404（返回 null 交给 AssetLoader 默认处理）。
 */
class DirectoryPathHandler(private val root: File) : WebViewAssetLoader.PathHandler {

    override fun handle(path: String): WebResourceResponse? {
        // WebViewAssetLoader 传入的是去掉域名后、已 URL 解码的相对路径。
        val relative = path.trimStart('/')
        if (relative.isEmpty()) return null

        // 双保险：显式拒绝 ".." 段 + canonical path 校验（对付 URL 编码绕过等花招）。
        val candidate = File(root, relative)
        val canonicalRoot = root.canonicalFile
        val canonicalCandidate = try {
            candidate.canonicalFile
        } catch (t: java.io.IOException) {
            Log.w("ZunoHtml", "canonicalize failed: $relative")
            return null
        }
        if (!canonicalCandidate.path.startsWith(canonicalRoot.path + File.separator)) {
            Log.w("ZunoHtml", "blocked path traversal attempt: $relative")
            return null
        }
        if (!canonicalCandidate.isFile) return null

        return try {
            val stream = FileInputStream(canonicalCandidate)
            val mime = MimeTypes.forFileName(canonicalCandidate.name)
            WebResourceResponse(mime.type, mime.charset, stream)
        } catch (_: FileNotFoundException) {
            null
        } catch (t: Throwable) {
            Log.w("ZunoHtml", "serve failed: $relative", t)
            null
        }
    }

    /** 与 shouldInterceptRequest 配套：拦截所有非本地请求（禁网）返回的 403 空响应。 */
    fun blockedResponse(): WebResourceResponse {
        return WebResourceResponse(
            "text/plain",
            "utf-8",
            403,
            "Blocked",
            mapOf("Zuno-Sandbox" to "network-disabled"),
            java.io.ByteArrayInputStream(ByteArray(0)),
        )
    }

    companion object {
        /** 判断请求是否应被拦截到 AssetLoader（即 appassets.local 源）。 */
        fun isLocalOrigin(uri: Uri, domain: String): Boolean =
            uri.host == domain
    }
}
