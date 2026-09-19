package dev.flutter.embedded_photo_picker

import android.annotation.SuppressLint
import android.net.Uri
import android.provider.MediaStore
import android.widget.photopicker.EmbeddedPhotoPickerFeatureInfo
import android.widget.photopicker.EmbeddedPhotoPickerUiCustomizationParams
import android.widget.photopicker.PhotoPickerSelectionParams
import java.time.Duration

internal const val UNSUPPORTED_FEATURE_ERROR = "unsupported_feature"

internal class UnsupportedPickerFeatureException(message: String) : IllegalArgumentException(message)

internal data class PickerFeatureRequest(
    val maxSelection: Int,
    val orderedSelection: Boolean,
    val themeNightMode: Int,
    val preselectedUris: List<String>,
    val accentColor: Long?,
    val mimeTypes: List<String>,
    val initialExpanded: Boolean?,
    val selection: Map<*, *>?,
    val navigation: Map<*, *>?,
    val requestLocationMetadata: Boolean,
    val ui: Map<*, *>?,
)

internal fun parsePickerFeatureRequest(
    options: Map<*, *>,
    selectedUris: List<String>,
    sdk: Int,
    extension: Int,
    expanded: Boolean,
    deviceMaxSelection: Int,
): PickerFeatureRequest {
    val maxSelection = (options["maxSelection"] as Number).toInt()
    require(maxSelection in 1..deviceMaxSelection) { "Selection limit exceeds device maximum" }
    val selection = options["selection"] as? Map<*, *>
    if (selection != null) {
        validateSelectionConstraintsSupport(
            selection,
            PickerAvailability.supportsSelectionConstraints(sdk, extension),
        )
    }
    val navigation = options["navigation"] as? Map<*, *>
    if (navigation != null) {
        validateNavigationOptions(navigation, sdk, extension, expanded)
    }
    val requestLocationMetadata = options["requestLocationMetadata"] as? Boolean ?: false
    validateLocationMetadataRequest(
        requestLocationMetadata,
        PickerAvailability.supportsExtension23Features(sdk, extension),
    )
    val ui = options["ui"] as? Map<*, *>
    validateUiCustomizationSupport(
        configured = ui != null,
        supported = PickerAvailability.supportsExtension23Features(sdk, extension),
    )
    return PickerFeatureRequest(
        maxSelection = maxSelection,
        orderedSelection = options["orderedSelection"] as? Boolean ?: false,
        themeNightMode = (options["themeNightMode"] as? Number)?.toInt() ?: 0,
        preselectedUris = selectedUris.toList(),
        accentColor = (options["accentColor"] as? Number)?.toLong(),
        mimeTypes = (options["mimeTypes"] as? List<*>)?.map { it as String }.orEmpty(),
        initialExpanded = if (PickerAvailability.supportsInitialExpandedState(sdk, extension)) {
            expanded
        } else null,
        selection = selection,
        navigation = navigation,
        requestLocationMetadata = requestLocationMetadata,
        ui = ui,
    )
}

@SuppressLint("NewApi")
internal object PickerFeatureBuilder {
    fun build(
        options: Map<*, *>,
        selectedUris: List<Uri>,
        sdk: Int,
        extension: Int,
        expanded: Boolean,
    ): EmbeddedPhotoPickerFeatureInfo {
        val request = parsePickerFeatureRequest(
            options = options,
            selectedUris = selectedUris.map(Uri::toString),
            sdk = sdk,
            extension = extension,
            expanded = expanded,
            deviceMaxSelection = MediaStore.getPickImagesMaxLimit(),
        )
        val builder = EmbeddedPhotoPickerFeatureInfo.Builder()
            .setMaxSelectionLimit(request.maxSelection)
            .setOrderedSelection(request.orderedSelection)
            .setThemeNightMode(request.themeNightMode)
            .setPreSelectedUris(request.preselectedUris.map(Uri::parse))
        request.initialExpanded?.let(builder::setPickerLaunchedInExpandedState)
        request.selection?.takeIf(::hasSelectionConstraints)?.let {
            builder.setSelectionParams(buildSelectionParams(it))
        }
        request.navigation?.let { applyNavigationOptions(builder, it, sdk, extension) }
        if (request.requestLocationMetadata) builder.setRequestLocationMetadata(true)
        request.ui?.let {
            builder.setEmbeddedUiCustomizationParams(buildUiCustomizationParams(it))
        }
        request.accentColor?.let(builder::setAccentColor)
        if (request.mimeTypes.isNotEmpty()) builder.setMimeTypes(request.mimeTypes)
        return builder.build()
    }

    private fun applyNavigationOptions(
        builder: EmbeddedPhotoPickerFeatureInfo.Builder,
        options: Map<*, *>,
        sdk: Int,
        extension: Int,
    ) {
        (options["highlightAlbum"] as? String)?.let {
            builder.setHighlightAlbumId(highlightAlbumValue(it))
        }
        (options["highlightSearchQuery"] as? String)?.let {
            builder.setHighlightSearchMediaTextQuery(it)
        }
        if (hasHighlight(options) && PickerAvailability.supportsInitialExpandedState(sdk, extension)) {
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

    private fun buildUiCustomizationParams(
        options: Map<*, *>,
    ): EmbeddedPhotoPickerUiCustomizationParams =
        EmbeddedPhotoPickerUiCustomizationParams.Builder()
            .setAspectRatio(gridAspectRatioValue(options["gridAspectRatio"] as? String))
            .setSelectionBarVisibleInExpandedMode(
                options["selectionBarVisibleInExpandedMode"] as? Boolean ?: true,
            )
            .build()
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

internal fun validateUiCustomizationSupport(configured: Boolean, supported: Boolean) {
    if (configured && !supported) {
        throw UnsupportedPickerFeatureException(
            "Embedded UI customization requires Android 17.1 or U SDK Extension 23",
        )
    }
}

internal fun gridAspectRatioValue(value: String?): Int = when (value) {
    null, "systemDefault" -> EmbeddedPhotoPickerUiCustomizationParams.ASPECT_RATIO_UNDEFINED
    "square" -> EmbeddedPhotoPickerUiCustomizationParams.ASPECT_RATIO_SQUARE_1_1
    "portrait9By16" -> EmbeddedPhotoPickerUiCustomizationParams.ASPECT_RATIO_PORTRAIT_9_16
    else -> throw IllegalArgumentException("Unknown grid aspect ratio: $value")
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
