package dev.flutter.embedded_photo_picker

import android.annotation.SuppressLint
import android.content.Context
import android.content.res.Configuration
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.provider.MediaStore
import android.view.SurfaceHolder
import android.view.SurfaceView
import android.view.View
import android.widget.photopicker.EmbeddedPhotoPickerClient
import android.widget.photopicker.EmbeddedPhotoPickerFeatureInfo
import android.widget.photopicker.EmbeddedPhotoPickerProviderFactory
import android.widget.photopicker.EmbeddedPhotoPickerSession
import android.widget.photopicker.PhotoPickerSelectionParams
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.platform.PlatformView
import java.time.Duration

internal const val UNSUPPORTED_FEATURE_ERROR = "unsupported_feature"

internal class UnsupportedPickerFeatureException(message: String) : IllegalArgumentException(message)

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
        val limit = (options["maxSelection"] as Number).toInt()
        require(limit in 1..MediaStore.getPickImagesMaxLimit()) { "Selection limit exceeds device maximum" }
        val builder = EmbeddedPhotoPickerFeatureInfo.Builder()
            .setMaxSelectionLimit(limit)
            .setOrderedSelection(options["orderedSelection"] as? Boolean ?: false)
            .setThemeNightMode((options["themeNightMode"] as? Number)?.toInt() ?: 0)
            .setPreSelectedUris(selected.toList())
        val extension = PickerAvailability.currentExtensionVersion()
        if (PickerAvailability.supportsInitialExpandedState(Build.VERSION.SDK_INT, extension)) {
            builder.setPickerLaunchedInExpandedState(expanded)
        }
        val selection = options["selection"] as? Map<*, *>
        if (selection != null) {
            validateSelectionConstraintsSupport(
                selection,
                PickerAvailability.supportsSelectionConstraints(Build.VERSION.SDK_INT, extension),
            )
        }
        if (selection != null && hasSelectionConstraints(selection)) {
            builder.setSelectionParams(buildSelectionParams(selection))
        }
        val navigation = options["navigation"] as? Map<*, *>
        if (navigation != null) {
            applyNavigationOptions(builder, navigation, extension)
        }
        val requestLocationMetadata = options["requestLocationMetadata"] as? Boolean ?: false
        validateLocationMetadataRequest(
            requestLocationMetadata,
            PickerAvailability.supportsExtension23Features(Build.VERSION.SDK_INT, extension),
        )
        if (requestLocationMetadata) builder.setRequestLocationMetadata(true)
        (options["accentColor"] as? Number)?.let { builder.setAccentColor(it.toLong()) }
        val mimeTypes = (options["mimeTypes"] as? List<*>)?.map { it as String }.orEmpty()
        if (mimeTypes.isNotEmpty()) builder.setMimeTypes(mimeTypes)
        return builder.build()
    }

    private fun applyNavigationOptions(
        builder: EmbeddedPhotoPickerFeatureInfo.Builder,
        options: Map<*, *>,
        extension: Int,
    ) {
        validateNavigationOptions(options, Build.VERSION.SDK_INT, extension, expanded)
        (options["highlightAlbum"] as? String)?.let {
            builder.setHighlightAlbumId(highlightAlbumValue(it))
        }
        (options["highlightSearchQuery"] as? String)?.let {
            builder.setHighlightSearchMediaTextQuery(it)
        }
        if (hasHighlight(options) &&
            PickerAvailability.supportsInitialExpandedState(Build.VERSION.SDK_INT, extension)) {
            builder.setHighlightType(highlightTypeValue(options["highlightType"] as? String))
        }
        (options["launchTab"] as? String)?.let {
            builder.setLaunchTab(launchTabValue(it))
        }
        (options["collapsedModeScrollingEnabled"] as? Boolean)?.let {
            builder.setCollapsedModeScrollingEnabled(it)
        }
    }

    private fun buildSelectionParams(options: Map<*, *>): PhotoPickerSelectionParams {
        val builder = PhotoPickerSelectionParams.Builder()
        (options["minMediaItemResolutionInPixels"] as? Number)?.let {
            builder.setMinMediaItemResolutionInPixels(it.toLong())
        }
        (options["maxMediaItemResolutionInPixels"] as? Number)?.let {
            builder.setMaxMediaItemResolutionInPixels(it.toLong())
        }
        (options["maxMediaItemSizeInBytes"] as? Number)?.let {
            builder.setMaxMediaItemSizeInBytes(it.toLong())
        }
        (options["maxSelectionBatchSizeInBytes"] as? Number)?.let {
            builder.setMaxSelectionBatchSizeInBytes(it.toLong())
        }
        (options["minVideoDurationMillis"] as? Number)?.let {
            builder.setMinVideoDuration(Duration.ofMillis(it.toLong()))
        }
        (options["maxVideoDurationMillis"] as? Number)?.let {
            builder.setMaxVideoDuration(Duration.ofMillis(it.toLong()))
        }
        val mimeTypes = (options["mimeTypes"] as? List<*>)?.map { it as String }.orEmpty()
        if (mimeTypes.isNotEmpty()) builder.setMimeTypes(mimeTypes)
        return builder.build()
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

internal fun readInitialExpanded(options: Map<*, *>): Boolean =
    options["initialExpanded"] as? Boolean ?: true

internal fun hasSelectionConstraints(options: Map<*, *>): Boolean =
    options.any { (_, value) -> value != null && (value !is List<*> || value.isNotEmpty()) }

internal fun validateSelectionConstraintsSupport(options: Map<*, *>, supported: Boolean) {
    if (hasSelectionConstraints(options) && !supported) {
        throw UnsupportedPickerFeatureException(
            "Selection constraints require Android 17 or U SDK Extension 22",
        )
    }
}

internal fun validateLocationMetadataRequest(requested: Boolean, supported: Boolean) {
    if (requested && !supported) {
        throw UnsupportedPickerFeatureException(
            "Location metadata requires Android 17.1 or U SDK Extension 23",
        )
    }
}

internal fun hasHighlight(options: Map<*, *>): Boolean =
    options["highlightAlbum"] != null || options["highlightSearchQuery"] != null

internal fun validateNavigationOptions(
    options: Map<*, *>,
    sdk: Int,
    extension: Int,
    initialExpanded: Boolean,
) {
    val hasAlbum = options["highlightAlbum"] != null
    val hasQuery = options["highlightSearchQuery"] != null
    require(!(hasAlbum && hasQuery)) { "Only one highlight source may be set" }
    if ((hasAlbum || hasQuery) && !PickerAvailability.supportsHighlights(sdk, extension)) {
        throw UnsupportedPickerFeatureException(
            "Highlights require Android 17 or U SDK Extension 19",
        )
    }
    if (hasHighlight(options) && options["highlightType"] == "expanded") {
        if (!PickerAvailability.supportsInitialExpandedState(sdk, extension)) {
            throw UnsupportedPickerFeatureException(
                "Expanded highlights require Android 17 or U SDK Extension 21",
            )
        }
        require(initialExpanded) { "Expanded highlights require an initially expanded picker" }
    }
    if ((options["launchTab"] != null || options["collapsedModeScrollingEnabled"] != null) &&
        !PickerAvailability.supportsExtension23Features(sdk, extension)) {
        throw UnsupportedPickerFeatureException(
            "Launch tab and collapsed scrolling require Android 17.1 or U SDK Extension 23",
        )
    }
}

internal fun launchTabValue(value: String): Int = when (value) {
    "photos" -> EmbeddedPhotoPickerFeatureInfo.TAB_IMAGES
    "collections" -> EmbeddedPhotoPickerFeatureInfo.TAB_ALBUMS
    else -> throw IllegalArgumentException("Unknown launch tab: $value")
}

internal fun highlightTypeValue(value: String?): Int = when (value) {
    null, "collapsed" -> MediaStore.PICK_IMAGES_HIGHLIGHT_TYPE_COLLAPSED
    "expanded" -> MediaStore.PICK_IMAGES_HIGHLIGHT_TYPE_EXPANDED
    else -> throw IllegalArgumentException("Unknown highlight type: $value")
}

internal fun highlightAlbumValue(value: String): String = when (value) {
    "favorites" -> MediaStore.PICK_IMAGES_HIGHLIGHT_ALBUM_FAVORITES
    "camera" -> MediaStore.PICK_IMAGES_HIGHLIGHT_ALBUM_CAMERA
    "screenshots" -> MediaStore.PICK_IMAGES_HIGHLIGHT_ALBUM_SCREENSHOTS
    "videos" -> MediaStore.PICK_IMAGES_HIGHLIGHT_ALBUM_VIDEOS
    "downloads" -> MediaStore.PICK_IMAGES_HIGHLIGHT_ALBUM_DOWNLOADS
    else -> throw IllegalArgumentException("Unknown highlight album: $value")
}
