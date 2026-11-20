package com.zuno.wallpaper.wallpaper.html

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.graphics.drawable.GradientDrawable
import android.os.Bundle
import android.view.Gravity
import android.view.ViewGroup
import android.webkit.WebView
import android.widget.FrameLayout
import android.widget.ImageView
import java.io.File

/**
 * HTML 壁纸的 App 内预览 Activity。
 *
 * 刻意与壁纸引擎共用 [SandboxedWebViewFactory]：预览看到的就是壁纸渲染的内容、
 * 同一套沙箱策略（禁 file://、禁网、只暴露 setConfig 桥）。
 * 预览页允许真实触摸交互（壁纸里触摸来自 Engine.onTouchEvent，这里是 View 系统原生分发）。
 */
class HtmlPreviewActivity : Activity() {

    private var webView: WebView? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        val packageDir = File(intent.getStringExtra(EXTRA_DIR) ?: error("dir required"))
        val entry = intent.getStringExtra(EXTRA_ENTRY) ?: error("entry required")
        val configJson = intent.getStringExtra(EXTRA_CONFIG) ?: "{}"

        val container = FrameLayout(this)
        container.setBackgroundColor(0xFF101014.toInt())

        webView = SandboxedWebViewFactory.create(
            context = this,
            packageRoot = packageDir,
            entryRelativePath = entry,
            configJson = configJson,
            onSetConfig = { key, value ->
                // 预览中的调整不写激活配置（可能预览的不是当前激活壁纸），仅回显。
                android.util.Log.d("ZunoHtmlPreview", "preview setConfig $key=$value")
            },
            onPageReady = { /* 预览无需额外处理 */ },
        )
        container.addView(
            webView,
            ViewGroup.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.MATCH_PARENT,
            ),
        )
        // 悬浮退出按钮：全屏预览没有系统返回条以外的可见出口，规格要求
        // 退出方式必须可感知（WebView 页面也可能拦截返回手势）。
        val density = resources.displayMetrics.density
        val closeButton = ImageView(this).apply {
            setImageResource(android.R.drawable.ic_menu_close_clear_cancel)
            setColorFilter(0xFFFFFFFF.toInt())
            background = GradientDrawable().apply {
                shape = GradientDrawable.OVAL
                setColor(0x66000000) // 半透明黑圆底，任何页面上可见
            }
            contentDescription = "退出预览"
        }
        val closeLp = FrameLayout.LayoutParams(
            (44 * density).toInt(),
            (44 * density).toInt(),
            Gravity.TOP or Gravity.END,
        ).apply {
            val margin = (16 * density).toInt()
            setMargins(margin, (48 * density).toInt(), margin, margin) // 顶部避开状态栏
        }
        container.addView(closeButton, closeLp)
        closeButton.setOnClickListener { finish() }
        setContentView(container)
    }

    override fun onBackPressed() {
        // 保持默认 finish 语义，显式写出来以表明不需要 WebView 历史回退。
        finish()
    }

    override fun onDestroy() {
        webView?.let {
            it.onPause()
            it.removeAllViews()
            it.destroy()
        }
        webView = null
        super.onDestroy()
    }

    companion object {
        private const val EXTRA_DIR = "zuno.dir"
        private const val EXTRA_ENTRY = "zuno.entry"
        private const val EXTRA_CONFIG = "zuno.config"

        fun intent(context: Context, dir: String, entry: String, configJson: String): Intent {
            return Intent(context, HtmlPreviewActivity::class.java)
                .putExtra(EXTRA_DIR, dir)
                .putExtra(EXTRA_ENTRY, entry)
                .putExtra(EXTRA_CONFIG, configJson)
        }
    }
}
