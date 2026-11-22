package com.zuno.wallpaper.wallpaper.html

import android.annotation.SuppressLint
import android.content.Context
import android.net.Uri
import android.util.Log
import android.webkit.WebChromeClient
import android.webkit.WebResourceRequest
import android.webkit.WebResourceResponse
import android.webkit.WebSettings
import android.webkit.WebView
import android.webkit.WebViewClient
import androidx.webkit.WebViewAssetLoader
import java.io.File

/**
 * 沙箱化 WebView 工厂：壁纸引擎与 App 内预览页共用，保证“预览 == 壁纸实际渲染”。
 *
 * 沙箱策略（与规格一致）：
 * 1. 本地资源一律通过 WebViewAssetLoader 以 https://appassets.local/ 提供，file:// 被禁用；
 * 2. shouldInterceptRequest 拦截一切未被 AssetLoader 命中的请求（包括外链图片/字体/脚本），
 *    返回 403 —— 壁纸默认禁网。规格中的 capabilities.network 需要用户二次确认后才放行，
 *    v1 实现选择完全不放行（见 README「平台限制」）；
 * 3. URL 导航只允许 appassets.local 源内的跳转；
 * 4. JS 桥只暴露 setConfig(key, value)；
 * 5. 权限请求（摄像头/麦克风/定位）一律拒绝。
 */
object SandboxedWebViewFactory {

    const val DOMAIN = "appassets.local"

    /**
     * 沙箱引导补丁：经 WebViewCompat.addDocumentStartJavaScript 注入，
     * 保证先于页面任何脚本执行。做三件事：
     *
     * 1. 禁网桩。shouldInterceptRequest 拦不到 WebSocket 握手与 WebRTC 流量
     *    （WebView 不把这两类请求路由给拦截器），恶意页面可用
     *    new WebSocket("wss://attacker/") 外联，绕过“壁纸默认禁网”的承诺。
     *    这里把构造器整体替换为抛错桩（含同源——壁纸没有任何合法的 WS 场景）。
     * 2. CSP meta 第二道防线。connect-src 'self'：拦截器覆盖不到的连接类流量
     *    （含 Worker 内部 fetch）由内核强制只许同源——不能用 'none'，rain 等
     *    壁纸会用 XHR/fetch 加载包内的着色器文件，'none' 会把它们打断。
     * 3. rAF 节流门。性能档位 MEDIUM 承诺 ~30fps：把 requestAnimationFrame
     *    包成按 __zunoFrameIntervalMs 节流的版本（0 = 不节流；LOW 档位由
     *    CSS 冻结 + JS 暂停接管，不需要门）。此前注入的 rAF 时间戳探针
     *    从未被消费、档位间隔字段也无人引用，MEDIUM 实际不生效。
     */
    private const val SANDBOX_BOOT_JS =
        "(function(){" +
            "var deny=function(name){return function(){throw new Error('ZUNO sandbox: '+name+' is disabled');};};" +
            "try{window.WebSocket=deny('WebSocket');}catch(e){}" +
            "try{window.RTCPeerConnection=deny('RTCPeerConnection');}catch(e){}" +
            "try{window.webkitRTCPeerConnection=deny('RTCPeerConnection');}catch(e){}" +
            "try{window.EventSource=deny('EventSource');}catch(e){}" +
            "try{if(navigator.serviceWorker){navigator.serviceWorker.register=deny('serviceWorker.register');}}catch(e){}" +
            "try{var m=document.createElement('meta');m.httpEquiv='Content-Security-Policy';" +
            "m.content=\"connect-src 'self'\";(document.head||document.documentElement).appendChild(m);}catch(e){}" +
            "if(!window.__zunoRafGate){window.__zunoRafGate=1;window.__zunoFrameIntervalMs=0;" +
            "var nativeRaf=window.requestAnimationFrame.bind(window);var last=0;" +
            "window.requestAnimationFrame=function(cb){" +
            "var iv=window.__zunoFrameIntervalMs|0;" +
            "if(iv<=0)return nativeRaf(cb);" +
            "var now=Date.now();var next=Math.max(last+iv,now);last=next;" +
            "return setTimeout(function(){nativeRaf(function(t){if(cb)cb(t);});},next-now);};}" +
            "})();"

    @SuppressLint("SetJavaScriptEnabled")
    fun create(
        context: Context,
        packageRoot: File,
        entryRelativePath: String,
        configJson: String,
        onSetConfig: (key: String, value: String) -> Unit,
        onPageReady: (WebView) -> Unit,
    ): WebView {

        val handler = DirectoryPathHandler(packageRoot)
        val assetLoader = WebViewAssetLoader.Builder()
            // appassets.androidplatform.net 是 Google 保留的默认域；换自定义域避免与
            // 其他应用的可预期行为混淆。域名不走公网 DNS（拦截发生在 WebView 内部）。
            .setDomain(DOMAIN)
            .addPathHandler("/", handler)
            .build()

        val webView = WebView(context)

        // 层类型：LAYER_TYPE_NONE 关闭 WebView 的离屏硬件层。
        // ZUNO 的壁纸路径是“离屏 WebView → 软件画布”（见 HtmlWallpaperEngine），
        // 硬件层在此链路中毫无收益，反而会额外消耗一块全屏 GPU 内存；
        // 规格亦提示此值需实测，故保留为常量便于后续 A/B。
        webView.setLayerType(WebView.LAYER_TYPE_NONE, null)

        webView.settings.apply {
            javaScriptEnabled = true // 交互壁纸必需；沙箱由“独立 https 源 + 禁网 + 无文件访问”保障
            domStorageEnabled = true // 页面自己的 localStorage 状态
            // 壁纸没有“用户手势”，自动播放动画/媒体必须允许。
            mediaPlaybackRequiresUserGesture = false
            // 文件与内容访问全关：这是禁 file:// 的最后一道闸。
            allowFileAccess = false
            allowContentAccess = false
            allowFileAccessFromFileURLs = false
            allowUniversalAccessFromFileURLs = false
            // 禁止弹窗 / 多窗口：壁纸页面不应该打开任何窗口。
            setSupportMultipleWindows(false)
            javaScriptCanOpenWindowsAutomatically = false
            setGeolocationEnabled(false)
            mixedContentMode = WebSettings.MIXED_CONTENT_NEVER_ALLOW
        }

        webView.webViewClient = object : WebViewClient() {
            override fun shouldInterceptRequest(
                view: WebView,
                request: WebResourceRequest,
            ): WebResourceResponse? {
                val url = request.url
                // 1) 本地资源 → AssetLoader（https://appassets.local/...）。
                assetLoader.shouldInterceptRequest(url)?.let { return it }
                // 2) 其余一切（http/https 外部主机）→ 403 禁网。
                //    必须返回响应而不是放行，否则 WebView 会发起真实网络请求。
                return handler.blockedResponse()
            }

            override fun shouldOverrideUrlLoading(view: WebView, request: WebResourceRequest): Boolean {
                val url = request.url
                // 只允许包内导航；外链/自定义 scheme 一律拦截。
                if (url.host == DOMAIN) return false
                Log.w("ZunoHtml", "blocked navigation to $url")
                return true
            }

            override fun onPageFinished(view: WebView, url: String?) {
                super.onPageFinished(view, url)
                // 配置以“注入全局变量”的方式给页面，避免页面通过桥读取任意信息。
                // （沙箱引导补丁已改为 document_start 注入，见 loadUrl 前的注册。）
                view.evaluateJavascript(
                    "window.__ZUNO_CONFIG__ = $configJson;",
                    null,
                )
                onPageReady(view)
            }
        }

        webView.webChromeClient = object : WebChromeClient() {
            override fun onPermissionRequest(request: android.webkit.PermissionRequest) {
                // 摄像头/麦克风等运行时权限在壁纸场景永远拒绝。
                request.deny()
            }

            override fun onGeolocationPermissionsShowPrompt(
                origin: String?,
                callback: android.webkit.GeolocationPermissions.Callback?,
            ) {
                callback?.invoke(origin, false, false)
            }

            override fun onConsoleMessage(message: android.webkit.ConsoleMessage?): Boolean {
                // console 只进 logcat，且限制长度，防止页面刷屏影响性能；
                // release 构建完全关闭（页面日志不属于线上可观测性范畴）。
                if (com.zuno.wallpaper.BuildConfig.DEBUG) {
                    val text = message?.message()?.take(200) ?: ""
                    Log.d("ZunoHtmlConsole", text)
                }
                return true
            }
        }

        webView.addJavascriptInterface(WallpaperJsBridge(onSetConfig), "ZunoWallpaper")

        // 沙箱引导补丁必须在页面任何脚本之前执行（禁网桩要抢在页面用 WebSocket
        // 之前替换构造器），evaluateJavascript 在 onPageFinished 里打已经晚了。
        // addDocumentStartJavaScript 由内核保证在文档创建时、页面脚本前运行。
        androidx.webkit.WebViewCompat.addDocumentStartJavaScript(
            webView,
            listOf(SANDBOX_BOOT_JS),
            setOf("https://$DOMAIN"),
        )

        val pageUrl = Uri.parse("https://$DOMAIN/").buildUpon()
            .appendEncodedPath(entryRelativePath.trimStart('/'))
            .build()
        webView.loadUrl(pageUrl.toString())
        return webView
    }
}
