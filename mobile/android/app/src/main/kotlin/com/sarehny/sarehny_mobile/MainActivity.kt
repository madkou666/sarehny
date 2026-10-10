package com.sarehny.sarehny_mobile

import android.content.Intent
import android.content.pm.ApplicationInfo
import android.net.Uri
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.sarehny/external_browser")
            .setMethodCallHandler { call, result ->
                if (call.method != "open") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }

                val uri = call.argument<String>("url")?.let(Uri::parse)
                if (uri == null) {
                    result.error("invalid_url", "A secure website URL is required.", null)
                    return@setMethodCallHandler
                }
                val isDebug = applicationInfo.flags and ApplicationInfo.FLAG_DEBUGGABLE != 0
                val secure = uri.scheme == "https"
                val localDebug = isDebug && uri.scheme == "http" &&
                    uri.host in setOf("localhost", "127.0.0.1", "10.0.2.2")
                if (uri.host.isNullOrBlank() || (!secure && !localDebug)) {
                    result.error("invalid_url", "A secure website URL is required.", null)
                    return@setMethodCallHandler
                }

                try {
                    startActivity(Intent(Intent.ACTION_VIEW, uri).addCategory(Intent.CATEGORY_BROWSABLE))
                    result.success(null)
                } catch (_: Exception) {
                    result.error("browser_unavailable", "No browser is available to open this page.", null)
                }
            }
    }
}
