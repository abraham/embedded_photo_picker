package dev.flutter.embedded_photo_picker

import android.os.Build
import android.os.ext.SdkExtensions

internal object PickerAvailability {
    fun supportsApi(sdk: Int, extension: Int): Boolean =
        sdk >= 36 || (sdk >= 34 && extension >= 15)

    fun supportsHighlights(sdk: Int, extension: Int): Boolean =
        sdk >= 37 || (sdk >= 34 && extension >= 19)

    fun supportsInitialExpandedState(sdk: Int, extension: Int): Boolean =
        sdk >= 37 || (sdk >= 34 && extension >= 21)

    fun supportsSelectionConstraints(sdk: Int, extension: Int): Boolean =
        sdk >= 37 || (sdk >= 34 && extension >= 22)

    fun supportsExtension23Features(sdk: Int, extension: Int): Boolean =
        sdk >= 38 || (sdk >= 34 && extension >= 23)

    fun currentExtensionVersion(sdk: Int = Build.VERSION.SDK_INT): Int =
        if (sdk >= 34) SdkExtensions.getExtensionVersion(34) else 0

    fun toMap(sdk: Int, extension: Int, available: Boolean): Map<String, Any> {
        val extension23 = supportsExtension23Features(sdk, extension)
        return mapOf(
            "available" to available,
            "androidApiLevel" to sdk,
            "uExtensionVersion" to extension,
            "supportsHighlights" to supportsHighlights(sdk, extension),
            "supportsInitialExpandedState" to supportsInitialExpandedState(sdk, extension),
            "supportsSelectionConstraints" to supportsSelectionConstraints(sdk, extension),
            "supportsLaunchTab" to extension23,
            "supportsLocationMetadata" to extension23,
            "supportsCollapsedModeScrolling" to extension23,
            "supportsEmbeddedUiCustomization" to extension23,
        )
    }
}
