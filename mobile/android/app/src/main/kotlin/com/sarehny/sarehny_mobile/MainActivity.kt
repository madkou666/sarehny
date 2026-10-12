package com.sarehny.sarehny_mobile

import android.app.Activity
import android.content.Intent
import android.database.Cursor
import android.net.Uri
import android.provider.OpenableColumns
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream

class MainActivity : FlutterActivity() {
    private var imageResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "pickImage" -> pickImage(result)
                    else -> result.notImplemented()
                }
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

    companion object {
        private const val CHANNEL = "com.sarehny/platform"
        private const val IMAGE_REQUEST_CODE = 7202
        private const val MAX_IMAGE_BYTES = 10 * 1024 * 1024
    }
}
