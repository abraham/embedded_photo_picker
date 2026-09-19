package dev.flutter.embedded_photo_picker

import android.annotation.SuppressLint
import android.content.Context
import android.content.res.Configuration
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.view.SurfaceHolder
import android.view.SurfaceView
import android.view.View
import android.widget.photopicker.EmbeddedPhotoPickerClient
import android.widget.photopicker.EmbeddedPhotoPickerFeatureInfo
import android.widget.photopicker.EmbeddedPhotoPickerProviderFactory
import android.widget.photopicker.EmbeddedPhotoPickerSession
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.platform.PlatformView

@SuppressLint("NewApi")
internal class NativePickerView(
    context: Context,
    messenger: BinaryMessenger,
    viewId: Int,
    private val options: Map<*, *>,
    private val onDisposed: (NativePickerView) -> Unit,
) : SurfaceView(context), PlatformView, SurfaceHolder.Callback {
    private val channel = MethodChannel(messenger, "embedded_photo_picker/view/$viewId")
    private val handler = Handler(Looper.getMainLooper())
    private var session: EmbeddedPhotoPickerSession? = null
    private var disposed = false
    private var connected = false
    private var surfaceReady = false
    private var opening = false
    private var generation = 0
    private var expanded = readInitialExpanded(options)
    private var hostVisible = true
    private val selected = LinkedHashSet<Uri>()
    private val timeout = Runnable { fail("session_timeout", "Photo picker did not open") }

    init {
        setZOrderOnTop(true)
        (options["preselectedUris"] as? List<*>)?.forEach { selected.add(Uri.parse(it as String)) }
        holder.addCallback(this)
        channel.setMethodCallHandler(::onMethodCall)
    }

    override fun getView(): View = this

    private fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        if (disposed) {
            result.error("disposed", "Picker has been disposed", null)
            return
        }
        try {
            when (call.method) {
                "connect" -> {
                    connected = true
                    openIfReady()
                }
                "setExpanded" -> {
                    expanded = call.arguments as Boolean
                    session?.notifyPhotoPickerExpanded(expanded)
                        ?: throw IllegalStateException("Session is not ready")
                }
                "setVisible" -> {
                    hostVisible = call.arguments as Boolean
                    session?.notifyVisibilityChanged(hostVisible && windowVisibility == VISIBLE)
                        ?: throw IllegalStateException("Session is not ready")
                }
                "deselect" -> {
                    val uris = (call.arguments as List<*>).map { Uri.parse(it as String) }
                    require(uris.all { it.scheme == "content" && !it.authority.isNullOrEmpty() })
                    session?.requestRevokeUriPermission(uris)
                        ?: throw IllegalStateException("Session is not ready")
                    selected.removeAll(uris.toSet())
                }
                else -> {
                    result.notImplemented()
                    return
                }
            }
            result.success(null)
        } catch (error: Exception) {
            result.error("picker_command_failed", error.message, null)
        }
    }

    private fun features(): EmbeddedPhotoPickerFeatureInfo {
        val extension = PickerAvailability.currentExtensionVersion()
        return PickerFeatureBuilder.build(
            options = options,
            selectedUris = selected.toList(),
            sdk = Build.VERSION.SDK_INT,
            extension = extension,
            expanded = expanded,
        )
    }

    @Suppress("DEPRECATION")
    private fun openIfReady() {
        if (disposed || !connected || !surfaceReady || opening || session != null || width == 0 || height == 0) return
        val token = hostToken ?: return
        val displayId = display?.displayId ?: return
        opening = true
        val requestGeneration = ++generation
        handler.postDelayed(timeout, 30_000)
        try {
            EmbeddedPhotoPickerProviderFactory.create(context).openSession(
                token, displayId, width, height, features(), context.mainExecutor,
                object : EmbeddedPhotoPickerClient {
                    private fun active() = !disposed && requestGeneration == generation

                    override fun onSessionOpened(newSession: EmbeddedPhotoPickerSession) {
                        if (!active()) {
                            newSession.close()
                            return
                        }
                        handler.removeCallbacks(timeout)
                        opening = false
                        session = newSession
                        try {
                            setChildSurfacePackage(newSession.surfacePackage)
                            newSession.notifyPhotoPickerExpanded(expanded)
                            newSession.notifyVisibilityChanged(hostVisible && windowVisibility == VISIBLE)
                            emit("ready")
                        } catch (error: Exception) {
                            fail("session_error", error.message)
                        }
                    }

                    override fun onSessionError(cause: Throwable) {
                        if (active()) fail("session_error", cause.message)
                    }

                    override fun onUriPermissionGranted(uris: List<Uri>) {
                        if (!active()) return
                        selected.addAll(uris)
                        emit("granted", uris.map { it.toString() })
                    }

                    override fun onUriPermissionRevoked(uris: List<Uri>) {
                        if (!active()) return
                        selected.removeAll(uris.toSet())
                        emit("revoked", uris.map { it.toString() })
                    }

                    override fun onSelectionComplete() {
                        if (active()) emit("complete")
                    }
                },
            )
        } catch (error: UnsupportedPickerFeatureException) {
            fail(UNSUPPORTED_FEATURE_ERROR, error.message)
        } catch (error: Exception) {
            fail("session_error", error.message)
        }
    }

    private fun emit(method: String, arguments: Any? = null) {
        if (connected && !disposed) channel.invokeMethod(method, arguments)
    }

    private fun closeSession() {
        generation++
        handler.removeCallbacks(timeout)
        opening = false
        val previous = session
        session = null
        runCatching { previous?.close() }
    }

    private fun fail(code: String, message: String?) {
        closeSession()
        emit("error", mapOf("code" to code, "message" to message))
        connected = false
    }

    override fun surfaceCreated(holder: SurfaceHolder) {
        surfaceReady = true
        openIfReady()
    }

    override fun surfaceChanged(holder: SurfaceHolder, format: Int, width: Int, height: Int) {
        try {
            session?.notifyResized(width, height)
            openIfReady()
        } catch (error: Exception) {
            fail("session_error", error.message)
        }
    }

    override fun surfaceDestroyed(holder: SurfaceHolder) {
        surfaceReady = false
        closeSession()
    }

    override fun onConfigurationChanged(newConfig: Configuration) {
        super.onConfigurationChanged(newConfig)
        try {
            session?.notifyConfigurationChanged(newConfig)
        } catch (error: Exception) {
            fail("session_error", error.message)
        }
    }

    override fun onWindowVisibilityChanged(visibility: Int) {
        super.onWindowVisibilityChanged(visibility)
        try {
            session?.notifyVisibilityChanged(hostVisible && visibility == VISIBLE)
        } catch (error: Exception) {
            fail("session_error", error.message)
        }
    }

    override fun dispose() {
        if (disposed) return
        disposed = true
        closeSession()
        holder.removeCallback(this)
        channel.setMethodCallHandler(null)
        onDisposed(this)
    }
}
