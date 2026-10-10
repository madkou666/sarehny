package com.sarehny.sarehny_mobile

import android.app.Activity
import android.content.Intent
import android.graphics.Color
import android.net.Uri
import android.os.Bundle
import android.view.Gravity
import android.view.View
import android.webkit.CookieManager
import android.webkit.SslErrorHandler
import android.webkit.ValueCallback
import android.webkit.WebChromeClient
import android.webkit.WebResourceRequest
import android.webkit.WebResourceResponse
import android.webkit.WebSettings
import java.io.ByteArrayInputStream
import android.webkit.WebView
import android.webkit.WebViewClient
import android.widget.LinearLayout
import android.widget.ProgressBar
import android.widget.TextView
import android.widget.Toast
import android.net.http.SslError
import android.os.Build

class SiteWebViewActivity : Activity() {
    private lateinit var webView: WebView
    private lateinit var progress: ProgressBar
    private lateinit var origin: Uri
    private var initialSessionCookie: String? = null
    private var fileChooserCallback: ValueCallback<Array<Uri>>? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        val page = intent.getStringExtra(EXTRA_URL)?.let(Uri::parse)
        origin = intent.getStringExtra(EXTRA_ORIGIN)?.let(Uri::parse) ?: run {
            finish()
            return
        }
        initialSessionCookie = intent.getStringExtra(EXTRA_SESSION_COOKIE)
        if (page == null || !isTrustedTarget(page, origin) || !isAllowedOrigin(origin)) {
            Toast.makeText(this, "رابط صفحة الموقع غير آمن.", Toast.LENGTH_LONG).show()
            finish()
            return
        }

        val root = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setBackgroundColor(Color.rgb(6, 7, 10))
        }
        val toolbar = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
            setPadding(dp(16), 0, dp(16), 0)
            setBackgroundColor(Color.rgb(11, 13, 18))
        }
        val close = TextView(this).apply {
            text = "إغلاق"
            textSize = 14f
            setTextColor(Color.WHITE)
            setPadding(dp(8), dp(12), dp(12), dp(12))
            setOnClickListener { finishWithSession() }
        }
        val title = TextView(this).apply {
            text = "صراحة · ${page.host.orEmpty()}"
            textSize = 14f
            setTextColor(Color.WHITE)
            gravity = Gravity.CENTER
        }
        toolbar.addView(close, LinearLayout.LayoutParams(dp(64), dp(56)))
        toolbar.addView(title, LinearLayout.LayoutParams(0, dp(56), 1f))
        root.addView(toolbar, LinearLayout.LayoutParams(-1, dp(56)))

        progress = ProgressBar(this, null, android.R.attr.progressBarStyleHorizontal).apply {
            max = 100
            progress = 0
        }
        root.addView(progress, LinearLayout.LayoutParams(-1, dp(3)))

        webView = WebView(this)
        CookieManager.getInstance().setAcceptThirdPartyCookies(webView, false)
        webView.settings.apply {
            javaScriptEnabled = true
            domStorageEnabled = true
            allowFileAccess = false
            allowContentAccess = false
            javaScriptCanOpenWindowsAutomatically = false
            setSupportMultipleWindows(false)
            mixedContentMode = WebSettings.MIXED_CONTENT_NEVER_ALLOW
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) safeBrowsingEnabled = true
        }
        webView.webViewClient = object : WebViewClient() {
            override fun shouldOverrideUrlLoading(view: WebView, request: WebResourceRequest): Boolean =
                routeNavigation(request.url)

            @Suppress("DEPRECATION")
            override fun shouldOverrideUrlLoading(view: WebView, url: String): Boolean =
                routeNavigation(Uri.parse(url))

            override fun shouldInterceptRequest(view: WebView, request: WebResourceRequest): WebResourceResponse? {
                if (request.isForMainFrame && !isTrustedTarget(request.url, origin)) {
                    return WebResourceResponse("text/plain", "UTF-8", ByteArrayInputStream(ByteArray(0)))
                }
                return super.shouldInterceptRequest(view, request)
            }

            override fun onReceivedSslError(view: WebView, handler: SslErrorHandler, error: SslError) {
                handler.cancel()
            }
        }
        webView.webChromeClient = object : WebChromeClient() {
            override fun onShowFileChooser(
                view: WebView,
                callback: ValueCallback<Array<Uri>>,
                fileChooserParams: WebChromeClient.FileChooserParams,
            ): Boolean {
                if (fileChooserCallback != null) fileChooserCallback?.onReceiveValue(null)
                fileChooserCallback = callback
                return try {
                    startActivityForResult(fileChooserParams.createIntent(), FILE_CHOOSER_REQUEST_CODE)
                    true
                } catch (_: Exception) {
                    fileChooserCallback = null
                    callback.onReceiveValue(null)
                    false
                }
            }

            override fun onProgressChanged(view: WebView, newProgress: Int) {
                progress.progress = newProgress
                progress.visibility = if (newProgress >= 100) View.GONE else View.VISIBLE
            }
        }
        root.addView(webView, LinearLayout.LayoutParams(-1, 0, 1f))
        setContentView(root)

        val cookie = initialSessionCookie
        if (cookie != null && SESSION_COOKIE.matches(cookie)) {
            val secureAttribute = if (origin.scheme == "https") "; Secure" else ""
            CookieManager.getInstance().apply {
                setAcceptCookie(true)
                setCookie(
                    origin.toString(),
                    "$cookie; Path=/; HttpOnly; SameSite=Lax$secureAttribute",
                ) { accepted ->
                    if (accepted) {
                        CookieManager.getInstance().flush()
                        webView.loadUrl(page.toString())
                    } else {
                        Toast.makeText(this@SiteWebViewActivity, "تعذّر مشاركة جلسة الموقع الآمنة.", Toast.LENGTH_LONG).show()
                        finishWithSession()
                    }
                }
            }
        } else {
            webView.loadUrl(page.toString())
        }
    }

    private fun routeNavigation(target: Uri): Boolean {
        if (isTrustedTarget(target, origin)) return false
        if (origin.scheme == "https" && target.scheme == "http" && target.host.equals(origin.host, ignoreCase = true)) {
            Toast.makeText(this, "تم حظر رابط غير مشفر إلى موقع صراحة.", Toast.LENGTH_SHORT).show()
            return true
        }
        if (target.scheme == "https" || target.scheme == "http" || target.scheme == "mailto" || target.scheme == "tel") {
            try {
                startActivity(Intent(Intent.ACTION_VIEW, target).addCategory(Intent.CATEGORY_BROWSABLE))
            } catch (_: Exception) {
                Toast.makeText(this, "تعذّر فتح الرابط الخارجي.", Toast.LENGTH_SHORT).show()
            }
        }
        return true
    }

    private fun isTrustedTarget(target: Uri, trustedOrigin: Uri): Boolean =
        target.scheme == trustedOrigin.scheme &&
            target.host.equals(trustedOrigin.host, ignoreCase = true) &&
            target.port == trustedOrigin.port &&
            target.userInfo == null

    private fun isAllowedOrigin(uri: Uri): Boolean {
        if (uri.userInfo != null || uri.host.isNullOrBlank() || uri.query != null || uri.fragment != null) return false
        if (uri.scheme == "https") return true
        val localDebugHost = uri.host in setOf("localhost", "127.0.0.1", "10.0.2.2")
        return BuildConfig.DEBUG && uri.scheme == "http" && localDebugHost
    }

    private fun finishWithSession() {
        val cookies = try {
            CookieManager.getInstance().getCookie(origin.toString())
        } catch (_: Exception) {
            null
        }
        val currentCookie = cookies
            ?.split(';')
            ?.map { it.trim() }
            ?.firstOrNull { it.startsWith("PHPSESSID=") }
            ?.takeIf { SESSION_COOKIE.matches(it) }
        val result = Intent().apply {
            if (currentCookie != null) putExtra(EXTRA_SESSION_COOKIE, currentCookie)
        }
        setResult(Activity.RESULT_OK, result)
        finish()
    }

    @Deprecated("Handled for the Android WebView file chooser")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != FILE_CHOOSER_REQUEST_CODE) return
        val callback = fileChooserCallback ?: return
        fileChooserCallback = null
        val uris = if (resultCode == Activity.RESULT_OK) {
            val clipData = data?.clipData
            when {
                clipData != null -> Array(clipData.itemCount) { index -> clipData.getItemAt(index).uri }
                data?.data != null -> arrayOf(data.data!!)
                else -> null
            }
        } else null
        callback.onReceiveValue(uris)
    }

    override fun onBackPressed() {
        if (::webView.isInitialized && webView.canGoBack()) webView.goBack() else finishWithSession()
    }

    override fun onDestroy() {
        fileChooserCallback?.onReceiveValue(null)
        fileChooserCallback = null
        if (::webView.isInitialized) {
            webView.stopLoading()
            webView.destroy()
        }
        super.onDestroy()
    }

    private fun dp(value: Int): Int = (value * resources.displayMetrics.density).toInt()

    companion object {
        const val EXTRA_URL = "site_url"
        const val EXTRA_ORIGIN = "site_origin"
        const val EXTRA_SESSION_COOKIE = "session_cookie"
        private val SESSION_COOKIE = Regex("^PHPSESSID=[A-Za-z0-9,-]{8,256}$")
    }
}
