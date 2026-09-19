import 'package:flutter/widgets.dart';

/// Creation-time settings for an embedded photo picker session.
///
/// Create a new widget key to apply different options to an existing picker.
class EmbeddedPhotoPickerOptions {
  /// Creates options, rejecting invalid limits, MIME types, URIs, and colors.
  EmbeddedPhotoPickerOptions({
    this.maxSelection = 1,
    List<String> mimeTypes = const [],
    List<Uri> preselectedUris = const [],
    this.accentColor,
    this.brightness,
    this.orderedSelection = false,
  }) : mimeTypes = List.unmodifiable(mimeTypes),
       preselectedUris = List.unmodifiable(preselectedUris) {
    if (maxSelection < 1) {
      throw ArgumentError.value(
        maxSelection,
        'maxSelection',
        'Must be positive',
      );
    }
    if (preselectedUris.length > maxSelection ||
        preselectedUris.toSet().length != preselectedUris.length) {
      throw ArgumentError(
        'Preselected URIs must be unique and within the limit',
      );
    }
    for (final uri in preselectedUris) {
      if (uri.scheme != 'content' || uri.authority.isEmpty) {
        throw ArgumentError.value(
          uri,
          'preselectedUris',
          'Expected content URI',
        );
      }
    }
    for (final mimeType in mimeTypes) {
      if (!RegExp(r'^(image|video)/([a-zA-Z0-9.+_-]+|\*)$')
          .hasMatch(mimeType)) {
        throw ArgumentError.value(mimeType, 'mimeTypes', 'Expected media MIME');
      }
    }
    final luminance = accentColor?.computeLuminance();
    if (luminance != null && (luminance < 0.05 || luminance > 0.9)) {
      throw ArgumentError.value(
        accentColor,
        'accentColor',
        'Invalid luminance',
      );
    }
  }

  /// The selection limit, also checked against Android's device maximum.
  final int maxSelection;

  /// Image and video MIME filters, or an empty list for all media.
  final List<String> mimeTypes;

  /// Previously granted content URIs to preselect where Android permits.
  final List<Uri> preselectedUris;

  /// The primary color, with luminance between 0.05 and 0.9; alpha is ignored.
  final Color? accentColor;

  /// The picker brightness, or `null` to follow the device theme.
  final Brightness? brightness;

  /// Whether Android should display selection order.
  final bool orderedSelection;

  /// Encodes creation settings for the Android view.
  Map<String, Object?> toMap() => {
    'maxSelection': maxSelection,
    'mimeTypes': mimeTypes,
    'preselectedUris': preselectedUris.map((uri) => uri.toString()).toList(),
    'accentColor': accentColor?.withValues(alpha: 1).toARGB32(),
    'themeNightMode': switch (brightness) {
      Brightness.light => 0x10,
      Brightness.dark => 0x20,
      null => 0,
    },
    'orderedSelection': orderedSelection,
  };
}
