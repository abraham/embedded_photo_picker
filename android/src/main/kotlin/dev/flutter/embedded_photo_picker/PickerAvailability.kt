package dev.flutter.embedded_photo_picker

internal object PickerAvailability {
    fun supportsApi(sdk: Int, extension: Int): Boolean =
        sdk >= 36 || (sdk >= 34 && extension >= 15)

    fun supportsInitialExpandedState(sdk: Int, extension: Int): Boolean =
        sdk >= 37 || (sdk >= 34 && extension >= 21)
}
