package com.sarehny.sarehny_mobile

import android.app.Activity
import android.content.Intent
import android.content.pm.ApplicationInfo
import android.database.Cursor
import android.net.Uri
import android.provider.OpenableColumns
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.MethodCall
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream

class MainActivity : FlutterActivity() {
    private var siteResult: MethodChannel.Result? = null
    private var imageResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "openSite" -> openSite(call, result)
                    "pickImage" -> pickImage(result)
                    else -> result.notImplemented()
                }
            }
    }

    private fun openSite(call: MethodCall, result: MethodChannel.Result) {
        if (siteResult != null) {
            result.error("site_already_open", "صفحة موقع مفتوحة بالفعل.", null)
            return
        }
        val url = call.argument<String>("url")?.let(Uri::parse)
        val origin = call.argument<String>("origin")?.let(Uri::parse)
        val cookie = call.argument<String>("sessionCookie")
        if (url == null || origin == null || !isTrustedTarget(url, origin) || !isAllowedOrigin(origin)) {
            result.error("invalid_url", "يجب فتح صفحة آمنة من نفس نطاق الموقع.", null)
            return
        }
        if (cookie != null && !SESSION_COOKIE.matches(cookie)) {
            result.error("invalid_session", "بيانات جلسة الموقع غير صالحة.", null)
            return
        }
        try {
            val intent = Intent(this, SiteWebViewActivity::class.java)
                .putExtra(SiteWebViewActivity.EXTRA_URL, url.toString())
                .putExtra(SiteWebViewActivity.EXTRA_ORIGIN, origin.toString())
            if (cookie != null) intent.putExtra(SiteWebViewActivity.EXTRA_SESSION_COOKIE, cookie)
            siteResult = result
            startActivityForResult(intent, SITE_REQUEST_CODE)
        } catch (_: Exception) {
            siteResult = null
            result.error("site_unavailable", "تعذّر فتح صفحة الموقع الآمنة.", null)
        }
    }

    private fun pickImage(result: MethodChannel.Result) {
        if (imageResult != null) {
            result.error("picker_already_open", "An image picker is already open.", null)
            return
        }
        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
            addCategory(Intent.CATEGORY_OPENABLE)
            type = "image/*"
            putExtra(Intent.EXTRA_MIME_TYPES, arrayOf("image/jpeg", "image/png", "image/webp", "image/gif"))
        }
        try {
            imageResult = result
            startActivityForResult(intent, IMAGE_REQUEST_CODE)
        } catch (_: Exception) {
            imageResult = null
            result.error("picker_unavailable", "لا يتوفر منتقي صور على هذا الجهاز.", null)
        }
    }

    @Deprecated("Handled for Flutter platform channel activities")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        when (requestCode) {
            SITE_REQUEST_CODE -> {
                val result = siteResult ?: return
                siteResult = null
                val cookie = data?.getStringExtra(SiteWebViewActivity.EXTRA_SESSION_COOKIE)
                result.success(if (cookie == null) emptyMap<String, Any>() else mapOf("sessionCookie" to cookie))
            }
            IMAGE_REQUEST_CODE -> {
                val result = imageResult ?: return
                imageResult = null
                if (resultCode != Activity.RESULT_OK || data?.data == null) {
                    result.success(null)
                    return
                }
                try {
                    result.success(readImage(data.data!!))
                } catch (error: IllegalArgumentException) {
                    result.error("invalid_image", error.message ?: "اختر صورة مدعومة لا تتجاوز ١٠ ميجابايت.", null)
                } catch (_: Exception) {
                    result.error("image_read_failed", "تعذّرت قراءة الصورة المختارة.", null)
                }
            }
        }
    }

    private fun readImage(uri: Uri): Map<String, Any> {
        val mimeType = contentResolver.getType(uri)?.lowercase()
            ?: throw IllegalArgumentException("Choose a JPG, PNG, WEBP, or GIF image.")
        val extension = when (mimeType) {
            "image/jpeg" -> "jpg"
            "image/png" -> "png"
            "image/webp" -> "webp"
            "image/gif" -> "gif"
            else -> throw IllegalArgumentException("Choose a JPG, PNG, WEBP, or GIF image.")
        }
        val stream = contentResolver.openInputStream(uri)
            ?: throw IllegalArgumentException("The selected image could not be read.")
        val output = ByteArrayOutputStream()
        stream.use { input ->
            val buffer = ByteArray(16 * 1024)
            var total = 0
            while (true) {
                val count = input.read(buffer)
                if (count < 0) break
                total += count
                if (total > MAX_IMAGE_BYTES) throw IllegalArgumentException("The image must be 10 MB or smaller.")
                output.write(buffer, 0, count)
            }
        }
        if (output.size() == 0) throw IllegalArgumentException("The selected image is empty.")
        val fileName = queryDisplayName(uri)?.takeIf { it.isNotBlank() } ?: "avatar.$extension"
        return mapOf("bytes" to output.toByteArray(), "mimeType" to mimeType, "fileName" to fileName)
    }

    private fun queryDisplayName(uri: Uri): String? {
        var cursor: Cursor? = null
        return try {
            cursor = contentResolver.query(uri, arrayOf(OpenableColumns.DISPLAY_NAME), null, null, null)
            if (cursor != null && cursor.moveToFirst()) {
                cursor.getString(cursor.getColumnIndexOrThrow(OpenableColumns.DISPLAY_NAME))
            } else null
        } finally {
            cursor?.close()
        }
    }

    private fun isTrustedTarget(target: Uri, origin: Uri): Boolean =
        target.scheme == origin.scheme &&
            target.host.equals(origin.host, ignoreCase = true) &&
            target.port == origin.port &&
            target.userInfo == null

    private fun isAllowedOrigin(uri: Uri): Boolean {
        if (uri.userInfo != null || uri.host.isNullOrBlank() || uri.query != null || uri.fragment != null) return false
        if (uri.scheme == "https") return true
        val localDebugHost = uri.host in setOf("localhost", "127.0.0.1", "10.0.2.2")
        val isDebug = applicationInfo.flags and ApplicationInfo.FLAG_DEBUGGABLE != 0
        return isDebug && uri.scheme == "http" && localDebugHost
    }

    companion object {
        private const val CHANNEL = "com.sarehny/platform"
        private const val SITE_REQUEST_CODE = 7201
        private const val IMAGE_REQUEST_CODE = 7202
        private const val MAX_IMAGE_BYTES = 10 * 1024 * 1024
        private val SESSION_COOKIE = Regex("^PHPSESSID=[A-Za-z0-9,-]{8,256}$")
    }
}
