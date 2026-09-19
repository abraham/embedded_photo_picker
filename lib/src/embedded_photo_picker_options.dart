import 'package:flutter/widgets.dart';

final _mediaMimeType = RegExp(r'^(image|video)/([a-zA-Z0-9.+_-]+|\*)$');

void _validateMimeTypes(List<String> mimeTypes, String argumentName) {
  for (final mimeType in mimeTypes) {
    if (!_mediaMimeType.hasMatch(mimeType)) {
      throw ArgumentError.value(mimeType, argumentName, 'Expected media MIME');
    }
  }
}

void _checkPositive(int? value, String argumentName) {
  if (value != null && value < 1) {
    throw ArgumentError.value(value, argumentName, 'Must be positive');
  }
}

/// Constraints that disable media which the host application cannot accept.
///
/// Requires Android 17/API 37 or U SDK Extension 22. Unlike [mimeTypes] on
/// [EmbeddedPhotoPickerOptions], [mimeTypes] here leave unmatched media visible
/// but unavailable for selection.
class EmbeddedPhotoPickerSelectionOptions {
  /// Creates selection constraints, rejecting invalid ranges and MIME types.
  EmbeddedPhotoPickerSelectionOptions({
    this.minMediaItemResolutionInPixels,
    this.maxMediaItemResolutionInPixels,
    this.maxMediaItemSizeInBytes,
    this.maxSelectionBatchSizeInBytes,
    this.minVideoDuration,
    this.maxVideoDuration,
    List<String> mimeTypes = const [],
  }) : mimeTypes = List.unmodifiable(mimeTypes) {
    _checkPositive(
      minMediaItemResolutionInPixels,
      'minMediaItemResolutionInPixels',
    );
    _checkPositive(
      maxMediaItemResolutionInPixels,
      'maxMediaItemResolutionInPixels',
    );
    _checkPositive(maxMediaItemSizeInBytes, 'maxMediaItemSizeInBytes');
    _checkPositive(
      maxSelectionBatchSizeInBytes,
      'maxSelectionBatchSizeInBytes',
    );
    if (minMediaItemResolutionInPixels != null &&
        maxMediaItemResolutionInPixels != null &&
        minMediaItemResolutionInPixels! > maxMediaItemResolutionInPixels!) {
      throw ArgumentError('Minimum media resolution cannot exceed the maximum');
    }
    if (minVideoDuration != null && minVideoDuration!.inMilliseconds < 1) {
      throw ArgumentError.value(
        minVideoDuration,
        'minVideoDuration',
        'Must be at least one millisecond',
      );
    }
    if (maxVideoDuration != null && maxVideoDuration!.inMilliseconds < 1) {
      throw ArgumentError.value(
        maxVideoDuration,
        'maxVideoDuration',
        'Must be at least one millisecond',
      );
    }
    if (minVideoDuration != null &&
        maxVideoDuration != null &&
        minVideoDuration! > maxVideoDuration!) {
      throw ArgumentError('Minimum video duration cannot exceed the maximum');
    }
    _validateMimeTypes(this.mimeTypes, 'mimeTypes');
  }

  /// The minimum total pixel count for a selectable media item.
  final int? minMediaItemResolutionInPixels;

  /// The maximum total pixel count for a selectable media item.
  final int? maxMediaItemResolutionInPixels;

  /// The maximum size of an individual selectable item.
  final int? maxMediaItemSizeInBytes;

  /// The maximum cumulative size of all selected items.
  final int? maxSelectionBatchSizeInBytes;

  /// The minimum selectable video duration, with millisecond precision.
  final Duration? minVideoDuration;

  /// The maximum selectable video duration, with millisecond precision.
  final Duration? maxVideoDuration;

  /// MIME types allowed for selection, or an empty list for all media.
  final List<String> mimeTypes;

  /// Encodes selection constraints for the Android view.
  Map<String, Object?> toMap() => {
    'minMediaItemResolutionInPixels': minMediaItemResolutionInPixels,
    'maxMediaItemResolutionInPixels': maxMediaItemResolutionInPixels,
    'maxMediaItemSizeInBytes': maxMediaItemSizeInBytes,
    'maxSelectionBatchSizeInBytes': maxSelectionBatchSizeInBytes,
    'minVideoDurationMillis': minVideoDuration?.inMilliseconds,
    'maxVideoDurationMillis': maxVideoDuration?.inMilliseconds,
    'mimeTypes': mimeTypes,
  };
}

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
    this.selection,
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
    _validateMimeTypes(this.mimeTypes, 'mimeTypes');
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

  /// Constraints for media that can be selected, when supported by Android.
  final EmbeddedPhotoPickerSelectionOptions? selection;

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
    'selection': selection?.toMap(),
  };
}
