import 'package:flutter/foundation.dart';

import 'picker_config.dart';

/// Device support for a specific [PickerConfig].
@immutable
class PickerSupport {
  /// Creates an immutable support result.
  PickerSupport({
    required this.available,
    required this.androidApiLevel,
    required this.uExtensionVersion,
    required Set<PickerFeature> supportedFeatures,
    required Set<PickerFeature> unsupportedFeatures,
  }) : supportedFeatures = Set.unmodifiable(supportedFeatures),
       unsupportedFeatures = Set.unmodifiable(unsupportedFeatures);

  /// Whether the base picker exists and every configured feature is supported.
  bool get isSupported => available && unsupportedFeatures.isEmpty;

  /// Whether this device supports [feature].
  bool supports(PickerFeature feature) => supportedFeatures.contains(feature);

  /// Whether the embedded picker service is available at all.
  final bool available;

  /// The Android API level, or zero outside Android.
  final int androidApiLevel;

  /// The Android U SDK Extension level, or zero when unavailable.
  final int uExtensionVersion;

  /// Optional features supported by this device.
  final Set<PickerFeature> supportedFeatures;

  /// Features required by the config but unavailable on this device.
  final Set<PickerFeature> unsupportedFeatures;
}
