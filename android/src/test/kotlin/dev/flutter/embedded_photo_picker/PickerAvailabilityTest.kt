package dev.flutter.embedded_photo_picker

import org.junit.Assert.assertFalse
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

    @Test fun readsInitialExpandedCreationParameter() {
        assertFalse(readInitialExpanded(mapOf("initialExpanded" to false)))
        assertTrue(readInitialExpanded(mapOf("initialExpanded" to true)))
        assertTrue(readInitialExpanded(emptyMap<Any, Any>()))
    }
}
