package com.danielux135.memorylux

import android.content.ContentValues
import android.os.Build
import android.provider.MediaStore
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

// registra un audio elegido por el usuario en MediaStore como sonido de
// notificación público, para que el proceso del sistema pueda reproducirlo
// (un file:// a la carpeta privada de la app no es legible desde fuera).
class MainActivity : FlutterActivity() {
    private val channelName = "memorylux/notification_sound"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                if (call.method == "registerSound") {
                    val sourcePath = call.argument<String>("sourcePath")
                    val displayName = call.argument<String>("displayName") ?: "memorylux_sound"
                    val mimeType = call.argument<String>("mimeType") ?: "audio/mpeg"
                    try {
                        result.success(registerSound(sourcePath, displayName, mimeType))
                    } catch (e: Exception) {
                        result.error("REGISTER_FAILED", e.message, null)
                    }
                } else {
                    result.notImplemented()
                }
            }
    }

    private fun registerSound(sourcePath: String?, displayName: String, mimeType: String): String? {
        if (sourcePath == null) return null
        val source = File(sourcePath)
        if (!source.exists()) return null

        val values = ContentValues().apply {
            put(MediaStore.Audio.Media.DISPLAY_NAME, displayName)
            put(MediaStore.Audio.Media.MIME_TYPE, mimeType)
            put(MediaStore.Audio.Media.IS_NOTIFICATION, 1)
            put(MediaStore.Audio.Media.IS_ALARM, 1)
            put(MediaStore.Audio.Media.IS_RINGTONE, 0)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                put(MediaStore.Audio.Media.RELATIVE_PATH, "Notifications/Memorylux")
                put(MediaStore.Audio.Media.IS_PENDING, 1)
            }
        }

        val itemUri = contentResolver.insert(MediaStore.Audio.Media.EXTERNAL_CONTENT_URI, values)
            ?: return null

        contentResolver.openOutputStream(itemUri)?.use { out ->
            source.inputStream().use { input -> input.copyTo(out) }
        } ?: return null

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            val done = ContentValues()
            done.put(MediaStore.Audio.Media.IS_PENDING, 0)
            contentResolver.update(itemUri, done, null, null)
        }

        return itemUri.toString()
    }
}
