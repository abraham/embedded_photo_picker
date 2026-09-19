package dev.flutter.embedded_photo_picker

import android.content.Context
import android.content.Intent
import android.os.Build
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.StandardMessageCodec
import io.flutter.plugin.platform.PlatformView
import io.flutter.plugin.platform.PlatformViewFactory

class EmbeddedPhotoPickerPlugin : FlutterPlugin {
    private var channel: MethodChannel? = null
    private var thumbnails: ThumbnailChannel? = null
    private val views = mutableSetOf<NativePickerView>()

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        thumbnails = ThumbnailChannel(binding.applicationContext, binding.binaryMessenger)
        channel = MethodChannel(binding.binaryMessenger, "embedded_photo_picker").also {
            it.setMethodCallHandler { call, result ->
                when (call.method) {
                    "isAvailable" -> result.success(isAvailable(binding.applicationContext))
                    "getCapabilities" -> result.success(capabilities(binding.applicationContext))
                    else -> result.notImplemented()
                }
            }
        }
        binding.platformViewRegistry.registerViewFactory(
            "embedded_photo_picker/view",
            object : PlatformViewFactory(StandardMessageCodec.INSTANCE) {
                override fun create(context: Context, viewId: Int, args: Any?): PlatformView {
                    check(isAvailable(context)) { "Embedded photo picker is unavailable" }
                    return NativePickerView(context, binding.binaryMessenger, viewId,
                        args as? Map<*, *> ?: emptyMap<Any, Any>(),
                        onDisposed = { views.remove(it) }).also { views.add(it) }
                }
            },
        )
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        thumbnails?.dispose()
        thumbnails = null
        views.toList().forEach { it.dispose() }
        views.clear()
        channel?.setMethodCallHandler(null)
        channel = null
    }

    private fun isAvailable(context: Context): Boolean {
        val extension = PickerAvailability.currentExtensionVersion()
        if (!PickerAvailability.supportsApi(Build.VERSION.SDK_INT, extension)) return false
        val intent = Intent("com.android.photopicker.core.embedded.EmbeddedService.BIND")
        return context.packageManager.queryIntentServices(intent, 0).isNotEmpty()
    }

    private fun capabilities(context: Context): Map<String, Any> {
        val sdk = Build.VERSION.SDK_INT
        val extension = PickerAvailability.currentExtensionVersion(sdk)
        return PickerAvailability.toMap(sdk, extension, isAvailable(context))
    }
}
