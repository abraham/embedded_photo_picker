package dev.flutter.embedded_photo_picker

import android.content.Context
import android.graphics.Bitmap
import android.net.Uri
import android.os.Build
import android.os.CancellationSignal
import android.os.Handler
import android.os.Looper
import android.util.Size
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream
import java.util.concurrent.Executors

internal class ThumbnailChannel(context: Context, messenger: BinaryMessenger) {
    private val resolver = context.contentResolver
    private val channel = MethodChannel(messenger, "embedded_photo_picker/media")
    private val executor = Executors.newFixedThreadPool(2)
    private val handler = Handler(Looper.getMainLooper())
    private val pending = mutableMapOf<CancellationSignal, MethodChannel.Result>()

    init {
        channel.setMethodCallHandler(::onMethodCall)
    }

    private fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        if (call.method != "loadThumbnail") {
            result.notImplemented()
            return
        }
        val args = call.arguments as? Map<*, *>
        val uri = (args?.get("uri") as? String)?.let(Uri::parse)
        val width = args?.get("width") as? Int
        val height = args?.get("height") as? Int
        if (uri == null || uri.scheme != "content" || uri.authority.isNullOrEmpty() ||
            width == null || width !in 1..1024 || height == null || height !in 1..1024) {
            result.error("invalid_arguments", "Expected a content URI and dimensions from 1 to 1024", null)
            return
        }
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) {
            result.error("unsupported_platform", "Thumbnails require Android 10 or newer", null)
            return
        }
        if (pending.size >= 32) {
            result.error("thumbnail_unavailable", "Too many pending thumbnail requests", null)
            return
        }
        val signal = CancellationSignal()
        pending[signal] = result
        executor.execute {
            try {
                val bitmap = resolver.loadThumbnail(uri, Size(width, height), signal)
                val bytes = try {
                    ByteArrayOutputStream().use { output ->
                        check(bitmap.compress(Bitmap.CompressFormat.PNG, 100, output))
                        output.toByteArray()
                    }
                } finally {
                    bitmap.recycle()
                }
                handler.post { pending.remove(signal)?.success(bytes) }
            } catch (error: Exception) {
                handler.post {
                    pending.remove(signal)?.error("thumbnail_unavailable", "Unable to load thumbnail", null)
                }
            }
        }
    }

    fun dispose() {
        channel.setMethodCallHandler(null)
        pending.forEach { (signal, result) ->
            signal.cancel()
            result.error("thumbnail_unavailable", "Flutter engine detached", null)
        }
        pending.clear()
        executor.shutdownNow()
    }
}