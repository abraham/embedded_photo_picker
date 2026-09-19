package dev.flutter.embedded_photo_picker

import android.provider.MediaStore
import android.widget.photopicker.EmbeddedPhotoPickerFeatureInfo
import org.junit.Assert.assertFalse
import org.junit.Assert.assertEquals
import org.junit.Assert.assertThrows
import org.junit.Assert.assertTrue
import org.junit.Test

class PickerAvailabilityTest {
    @Test fun requiresAndroid14ForExtensionBackport() {
        assertFalse(PickerAvailability.supportsApi(33, 15))
        assertFalse(PickerAvailability.supportsApi(34, 14))
        assertTrue(PickerAvailability.supportsApi(34, 15))
        assertTrue(PickerAvailability.supportsApi(35, 15))
    }

    @Test fun supportsFrameworkApiOnAndroid16AndLater() {
        assertTrue(PickerAvailability.supportsApi(36, 0))
        assertTrue(PickerAvailability.supportsApi(37, 0))
    }

    @Test fun gatesInitialExpandedFeature() {
        assertFalse(PickerAvailability.supportsInitialExpandedState(33, 21))
        assertFalse(PickerAvailability.supportsInitialExpandedState(34, 20))
        assertTrue(PickerAvailability.supportsInitialExpandedState(34, 21))
        assertTrue(PickerAvailability.supportsInitialExpandedState(36, 21))
        assertTrue(PickerAvailability.supportsInitialExpandedState(37, 0))
    }

    @Test fun gatesFeaturesAtEachExtensionBoundary() {
        assertFalse(PickerAvailability.supportsHighlights(34, 18))
        assertTrue(PickerAvailability.supportsHighlights(34, 19))
        assertFalse(PickerAvailability.supportsSelectionConstraints(35, 21))
        assertTrue(PickerAvailability.supportsSelectionConstraints(35, 22))
        assertTrue(PickerAvailability.supportsSelectionConstraints(37, 0))
        assertFalse(PickerAvailability.supportsExtension23Features(37, 22))
        assertTrue(PickerAvailability.supportsExtension23Features(37, 23))
        assertTrue(PickerAvailability.supportsExtension23Features(38, 0))
    }

    @Test fun capabilityMapKeepsBaseAvailabilitySeparateFromOptionalFeatures() {
        val capabilities = PickerAvailability.toMap(34, 22, available = false)

        assertFalse(capabilities["available"] as Boolean)
        assertTrue(capabilities["supportsHighlights"] as Boolean)
        assertTrue(capabilities["supportsSelectionConstraints"] as Boolean)
        assertFalse(capabilities["supportsLaunchTab"] as Boolean)
    }

    @Test fun readsInitialExpandedCreationParameter() {
        assertFalse(readInitialExpanded(mapOf("initialExpanded" to false)))
        assertTrue(readInitialExpanded(mapOf("initialExpanded" to true)))
        assertTrue(readInitialExpanded(emptyMap<Any, Any>()))
    }

    @Test fun detectsOnlyEffectiveSelectionConstraints() {
        assertFalse(hasSelectionConstraints(emptyMap<Any, Any>()))
        assertFalse(hasSelectionConstraints(mapOf("mimeTypes" to emptyList<String>())))
        assertFalse(hasSelectionConstraints(mapOf("maxMediaItemSizeInBytes" to null)))
        assertTrue(hasSelectionConstraints(mapOf("maxMediaItemSizeInBytes" to 1L)))
        assertTrue(hasSelectionConstraints(mapOf("mimeTypes" to listOf("image/jpeg"))))
    }

    @Test fun rejectsUnsupportedEffectiveSelectionConstraints() {
        validateSelectionConstraintsSupport(emptyMap<Any, Any>(), supported = false)
        val error = assertThrows(UnsupportedPickerFeatureException::class.java) {
            validateSelectionConstraintsSupport(
                mapOf("maxMediaItemSizeInBytes" to 1L),
                supported = false,
            )
        }

        assertEquals(
            "Selection constraints require Android 17 or U SDK Extension 22",
            error.message,
        )
        assertEquals("unsupported_feature", UNSUPPORTED_FEATURE_ERROR)
    }

    @Test fun locationMetadataIsOptInAndRequiresExtension23() {
        validateLocationMetadataRequest(requested = false, supported = false)
        validateLocationMetadataRequest(requested = true, supported = true)
        val error = assertThrows(UnsupportedPickerFeatureException::class.java) {
            validateLocationMetadataRequest(requested = true, supported = false)
        }

        assertEquals(
            "Location metadata requires Android 17.1 or U SDK Extension 23",
            error.message,
        )
    }

    @Test fun gatesNavigationFeaturesAtTheirOwnExtensionLevels() {
        validateNavigationOptions(
            mapOf("highlightAlbum" to "favorites", "highlightType" to "collapsed"),
            sdk = 34,
            extension = 19,
            initialExpanded = false,
        )
        assertThrows(UnsupportedPickerFeatureException::class.java) {
            validateNavigationOptions(
                mapOf("highlightSearchQuery" to "receipts"),
                sdk = 34,
                extension = 18,
                initialExpanded = true,
            )
        }
        assertThrows(UnsupportedPickerFeatureException::class.java) {
            validateNavigationOptions(
                mapOf("launchTab" to "collections"),
                sdk = 35,
                extension = 22,
                initialExpanded = true,
            )
        }
        validateNavigationOptions(
            mapOf("launchTab" to "collections", "collapsedModeScrollingEnabled" to true),
            sdk = 35,
            extension = 23,
            initialExpanded = true,
        )
    }

    @Test fun expandedHighlightsRequireSupportAndExpandedLaunch() {
        val options = mapOf("highlightAlbum" to "camera", "highlightType" to "expanded")
        assertThrows(UnsupportedPickerFeatureException::class.java) {
            validateNavigationOptions(options, sdk = 34, extension = 20, initialExpanded = true)
        }
        assertThrows(IllegalArgumentException::class.java) {
            validateNavigationOptions(options, sdk = 34, extension = 21, initialExpanded = false)
        }
        validateNavigationOptions(options, sdk = 34, extension = 21, initialExpanded = true)
    }

    @Test fun mapsNavigationEnumsToFrameworkConstants() {
        assertEquals(EmbeddedPhotoPickerFeatureInfo.TAB_IMAGES, launchTabValue("photos"))
        assertEquals(EmbeddedPhotoPickerFeatureInfo.TAB_ALBUMS, launchTabValue("collections"))
        assertEquals(
            MediaStore.PICK_IMAGES_HIGHLIGHT_TYPE_EXPANDED,
            highlightTypeValue("expanded"),
        )
        assertEquals(
            MediaStore.PICK_IMAGES_HIGHLIGHT_ALBUM_SCREENSHOTS,
            highlightAlbumValue("screenshots"),
        )
    }
}
