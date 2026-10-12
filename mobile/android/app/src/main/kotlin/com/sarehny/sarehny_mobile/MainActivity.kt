package com.sarehny.sarehny_mobile

import android.app.Activity
import android.content.Intent
import android.database.Cursor
import android.media.AudioAttributes
import android.media.MediaPlayer
import android.net.Uri
import android.provider.OpenableColumns
import java.io.File
import java.net.HttpURLConnection
import java.net.URL
import javax.net.ssl.HttpsURLConnection
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream

class MainActivity : FlutterActivity() {
    private var imageResult: MethodChannel.Result? = null
    private var voicePlayer: MediaPlayer? = null
    private var voiceMessageId: Int? = null
    private var voiceFile: File? = null
    private var voicePrepared = false
    private var voiceError: String? = null
    private var pendingVoiceResult: MethodChannel.Result? = null
    @Volatile private var voiceRequestGeneration = 0

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        cacheDir.listFiles()?.filter { it.name.startsWith("sarehny-voice-") }?.forEach { it.delete() }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "pickImage" -> pickImage(result)
                    "playVoice" -> playVoice(call, result)
                    "pauseVoice" -> controlVoice(call, result) { it.pause() }
                    "resumeVoice" -> controlVoice(call, result) {
                        if (it.currentPosition >= it.duration) it.seekTo(0)
                        it.start()
                    }
                    "seekVoice" -> seekVoice(call, result)
                    "voiceState" -> result.success(voiceState())
                    "stopVoice" -> stopVoice(call, result)
                    else -> result.notImplemented()
                }
            }
    }

    private fun playVoice(call: io.flutter.plugin.common.MethodCall, result: MethodChannel.Result) {
        val messageId = call.argument<Int>("messageId") ?: 0
        val url = call.argument<String>("url") ?: ""
        val expectedOrigin = call.argument<String>("origin") ?: ""
        val cookie = call.argument<String>("cookie") ?: ""
        val uri = runCatching { Uri.parse(url) }.getOrNull()
        val origin = runCatching { Uri.parse(expectedOrigin) }.getOrNull()
        val validTarget = messageId > 0 && uri != null && origin != null &&
            uri.scheme == "https" && uri.host == origin.host && uri.port == origin.port &&
            uri.userInfo == null && uri.fragment == null && origin.scheme == "https" &&
            origin.userInfo == null && origin.path.isNullOrEmpty() && uri.path == "/voice.php" &&
            uri.queryParameterNames == setOf("id") && uri.getQueryParameter("id") == messageId.toString()
        if (!validTarget || !Regex("^PHPSESSID=[A-Za-z0-9,-]{1,256}$").matches(cookie)) {
            result.error("invalid_voice_request", "طلب تشغيل الرسالة الصوتية غير صالح.", null)
            return
        }

        voiceRequestGeneration += 1
        val requestGeneration = voiceRequestGeneration
        pendingVoiceResult?.error("voice_replaced", "تم استبدال التشغيل بطلب صوتي آخر.", null)
        pendingVoiceResult = result
        clearVoicePlayback()
        voiceMessageId = messageId

        Thread {
            var downloadedFile: File? = null
            var connection: HttpsURLConnection? = null
            try {
                connection = (URL(url).openConnection() as? HttpsURLConnection)
                    ?: throw IllegalStateException("الاتصال الآمن غير متاح.")
                connection.instanceFollowRedirects = false
                connection.connectTimeout = 12_000
                connection.readTimeout = 30_000
                connection.requestMethod = "GET"
                connection.setRequestProperty("Accept", "audio/*")
                connection.setRequestProperty("Cookie", cookie)
                val status = connection.responseCode
                if (status != HttpURLConnection.HTTP_OK) {
                    throw IllegalStateException(
                        if (status == HttpURLConnection.HTTP_UNAUTHORIZED || status == HttpURLConnection.HTTP_FORBIDDEN)
                            "انتهت جلسة الدخول أو لم تعد تملك صلاحية هذه الرسالة."
                        else "تعذّر تنزيل التسجيل الصوتي (HTTP $status)."
                    )
                }
                val contentType = connection.contentType?.substringBefore(';')?.trim()?.lowercase().orEmpty()
                if (contentType !in VOICE_CONTENT_TYPES) {
                    throw IllegalStateException("استجابة الخادم ليست ملفًا صوتيًا صالحًا.")
                }
                if (connection.contentLength.toLong() > MAX_VOICE_BYTES) {
                    throw IllegalStateException("حجم التسجيل الصوتي أكبر من الحد المسموح.")
                }
                val tempFile = File.createTempFile("sarehny-voice-", ".audio", cacheDir)
                downloadedFile = tempFile
                connection.inputStream.use { input ->
                    tempFile.outputStream().use { output ->
                        val buffer = ByteArray(16 * 1024)
                        var total = 0L
                        while (true) {
                            val count = input.read(buffer)
                            if (count < 0) break
                            total += count
                            if (total > MAX_VOICE_BYTES) {
                                throw IllegalStateException("حجم التسجيل الصوتي أكبر من الحد المسموح.")
                            }
                            output.write(buffer, 0, count)
                        }
                    }
                }
                if (tempFile.length() == 0L) throw IllegalStateException("ملف التسجيل الصوتي فارغ.")
                val readyFile = tempFile
                runOnUiThread {
                    if (requestGeneration != voiceRequestGeneration) {
                        readyFile.delete()
                        if (pendingVoiceResult === result) pendingVoiceResult = null
                        result.success(null)
                    } else {
                        prepareVoicePlayer(messageId, readyFile, result)
                    }
                }
            } catch (error: Exception) {
                downloadedFile?.delete()
                val message = error.message ?: "تعذّر تشغيل الرسالة الصوتية."
                runOnUiThread {
                    if (requestGeneration == voiceRequestGeneration) {
                        voiceError = message
                        voiceMessageId = messageId
                        if (pendingVoiceResult === result) pendingVoiceResult = null
                        result.error("voice_playback_failed", message, null)
                    } else {
                        result.success(null)
                    }
                }
            } finally {
                connection?.disconnect()
            }
        }.start()
    }

    private fun prepareVoicePlayer(messageId: Int, file: File, result: MethodChannel.Result) {
        voiceFile = file
        voiceMessageId = messageId
        voiceError = null
        try {
            val player = MediaPlayer()
            voicePlayer = player
            player.setAudioAttributes(
                AudioAttributes.Builder()
                    .setUsage(AudioAttributes.USAGE_MEDIA)
                    .setContentType(AudioAttributes.CONTENT_TYPE_SPEECH)
                    .build()
            )
            player.setDataSource(file.absolutePath)
            player.setOnPreparedListener {
                voicePrepared = true
                try {
                    it.start()
                    if (pendingVoiceResult === result) pendingVoiceResult = null
                    result.success(null)
                } catch (error: Exception) {
                    voiceError = "تعذّر بدء تشغيل التسجيل الصوتي."
                    if (pendingVoiceResult === result) pendingVoiceResult = null
                    result.error("voice_playback_failed", voiceError, null)
                }
            }
            player.setOnErrorListener { _, what, extra ->
                voiceError = "تعذّر فك ترميز الرسالة الصوتية ($what/$extra)."
                voicePrepared = false
                if (pendingVoiceResult === result) {
                    pendingVoiceResult = null
                    result.error("voice_decode_failed", voiceError, null)
                }
                true
            }
            player.prepareAsync()
        } catch (error: Exception) {
            voiceError = error.message ?: "تعذّر تجهيز مشغل الصوت."
            if (pendingVoiceResult === result) pendingVoiceResult = null
            file.delete()
            voiceFile = null
            voicePlayer?.release()
            voicePlayer = null
            result.error("voice_playback_failed", voiceError, null)
        }
    }

    private fun controlVoice(
        call: io.flutter.plugin.common.MethodCall,
        result: MethodChannel.Result,
        action: (MediaPlayer) -> Unit,
    ) {
        val messageId = call.argument<Int>("messageId") ?: 0
        val player = voicePlayer
        if (messageId < 1 || messageId != voiceMessageId || player == null || !voicePrepared) {
            result.error("voice_not_ready", "الرسالة الصوتية غير جاهزة للتشغيل.", null)
            return
        }
        try {
            action(player)
            result.success(null)
        } catch (error: Exception) {
            result.error("voice_control_failed", error.message ?: "تعذّر التحكم بالتشغيل.", null)
        }
    }

    private fun seekVoice(call: io.flutter.plugin.common.MethodCall, result: MethodChannel.Result) {
        val messageId = call.argument<Int>("messageId") ?: 0
        val positionMs = call.argument<Int>("positionMs") ?: -1
        val player = voicePlayer
        if (messageId < 1 || messageId != voiceMessageId || player == null || !voicePrepared || positionMs < 0) {
            result.error("voice_not_ready", "تعذّر تغيير موضع التشغيل.", null)
            return
        }
        try {
            player.seekTo(positionMs.coerceAtMost(player.duration))
            result.success(null)
        } catch (error: Exception) {
            result.error("voice_seek_failed", error.message ?: "تعذّر تغيير موضع التشغيل.", null)
        }
    }

    private fun stopVoice(call: io.flutter.plugin.common.MethodCall, result: MethodChannel.Result) {
        val messageId = call.argument<Int>("messageId")
        if (messageId == null || messageId == voiceMessageId) {
            voiceRequestGeneration += 1
            pendingVoiceResult?.error("voice_cancelled", "أُوقف تشغيل الرسالة الصوتية.", null)
            pendingVoiceResult = null
            clearVoicePlayback()
        }
        result.success(null)
    }

    private fun voiceState(): Map<String, Any?> {
        val player = voicePlayer
        val position = if (player != null && voicePrepared) runCatching { player.currentPosition }.getOrDefault(0) else 0
        val duration = if (player != null && voicePrepared) runCatching { player.duration }.getOrDefault(0) else 0
        val isPlaying = if (player != null && voicePrepared) runCatching { player.isPlaying }.getOrDefault(false) else false
        return mapOf(
            "messageId" to voiceMessageId,
            "prepared" to voicePrepared,
            "isPlaying" to isPlaying,
            "positionMs" to position,
            "durationMs" to duration,
            "error" to voiceError,
        )
    }

    private fun clearVoicePlayback() {
        runCatching { voicePlayer?.reset() }
        runCatching { voicePlayer?.release() }
        voicePlayer = null
        voicePrepared = false
        voiceFile?.delete()
        voiceFile = null
        voiceMessageId = null
        voiceError = null
    }

    override fun onPause() {
        runCatching { if (voicePlayer?.isPlaying == true) voicePlayer?.pause() }
        super.onPause()
    }

    override fun onDestroy() {
        voiceRequestGeneration += 1
        pendingVoiceResult?.error("voice_cancelled", "أُغلق مشغل الصوت.", null)
        pendingVoiceResult = null
        clearVoicePlayback()
        super.onDestroy()
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
        private const val MAX_VOICE_BYTES = 7 * 1024 * 1024L
        private val VOICE_CONTENT_TYPES = setOf(
            "audio/webm", "audio/ogg", "audio/mp4", "audio/mpeg", "audio/wav"
        )
    }
}
