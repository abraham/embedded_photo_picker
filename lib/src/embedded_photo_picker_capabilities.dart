import 'package:flutter/foundation.dart';

/// Runtime support reported by the Android embedded photo picker.
///
/// Check these values before using options introduced after the base embedded
/// picker API. All values are false on non-Android platforms and when the
/// plugin is not registered.
@immutable
class EmbeddedPhotoPickerCapabilities {
  /// Creates an immutable capability snapshot.
  const EmbeddedPhotoPickerCapabilities({
    required this.available,
    required this.androidApiLevel,
    required this.uExtensionVersion,
    required this.supportsHighlights,
    required this.supportsInitialExpandedState,
    required this.supportsSelectionConstraints,
    required this.supportsLaunchTab,
    required this.supportsLocationMetadata,
    required this.supportsCollapsedModeScrolling,
    required this.supportsEmbeddedUiCustomization,
  });

  /// A capability snapshot for unsupported platforms or missing plugins.
  static const unavailable = EmbeddedPhotoPickerCapabilities(
    available: false,
    androidApiLevel: 0,
    uExtensionVersion: 0,
    supportsHighlights: false,
    supportsInitialExpandedState: false,
    supportsSelectionConstraints: false,
    supportsLaunchTab: false,
    supportsLocationMetadata: false,
    supportsCollapsedModeScrolling: false,
    supportsEmbeddedUiCustomization: false,
  );

  /// Whether the base embedded picker API and service are available.
  final bool available;

  /// The device's Android API level, or zero outside Android.
  final int androidApiLevel;

  /// The device's Android U SDK Extension version, or zero when unavailable.
  final int uExtensionVersion;

  /// Whether album and text-query highlights are supported.
  final bool supportsHighlights;

  /// Whether the initial expanded state can be declared at session creation.
  final bool supportsInitialExpandedState;

  /// Whether advanced media selection constraints are supported.
  final bool supportsSelectionConstraints;

  /// Whether choosing the initial Photos or Collections tab is supported.
  final bool supportsLaunchTab;

  /// Whether requesting location metadata is supported.
  final bool supportsLocationMetadata;

  /// Whether scrolling can be enabled in collapsed mode.
  final bool supportsCollapsedModeScrolling;

  /// Whether embedded-specific UI customization is supported.
  final bool supportsEmbeddedUiCustomization;

  /// Decodes a capability snapshot returned by Android.
  @internal
  factory EmbeddedPhotoPickerCapabilities.fromMap(Map<Object?, Object?> map) {
    bool flag(String key) => (map[key] as bool?) ?? false;

    return EmbeddedPhotoPickerCapabilities(
      available: flag('available'),
      androidApiLevel: (map['androidApiLevel'] as int?) ?? 0,
      uExtensionVersion: (map['uExtensionVersion'] as int?) ?? 0,
      supportsHighlights: flag('supportsHighlights'),
      supportsInitialExpandedState: flag('supportsInitialExpandedState'),
      supportsSelectionConstraints: flag('supportsSelectionConstraints'),
      supportsLaunchTab: flag('supportsLaunchTab'),
      supportsLocationMetadata: flag('supportsLocationMetadata'),
      supportsCollapsedModeScrolling: flag('supportsCollapsedModeScrolling'),
      supportsEmbeddedUiCustomization: flag('supportsEmbeddedUiCustomization'),
    );
  }
}
