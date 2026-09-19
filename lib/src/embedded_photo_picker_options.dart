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

/// The tab displayed when the embedded picker first opens.
enum EmbeddedPhotoPickerLaunchTab {
  /// The Photos tab.
  photos,

  /// The Collections tab.
  collections,
}

/// A system collection whose media should be highlighted.
enum EmbeddedPhotoPickerHighlightAlbum {
  /// Media marked as favorite.
  favorites,

  /// Media captured by the camera.
  camera,

  /// Screenshots.
  screenshots,

  /// Videos.
  videos,

  /// Downloaded media.
  downloads,
}

/// How highlighted media is presented when the picker opens.
enum EmbeddedPhotoPickerHighlightType {
  /// A highlighted section within the regular picker.
  collapsed,

  /// A full highlighted-results grid.
  ///
  /// The [EmbeddedPhotoPicker] widget must initially have `expanded: true`.
  expanded,
}

/// Thumbnail aspect ratios supported by the embedded picker media grid.
enum EmbeddedPhotoPickerGridAspectRatio {
  /// Let Android use its default grid aspect ratio.
  systemDefault,

  /// Square 1:1 thumbnails.
  square,

  /// Portrait 9:16 thumbnails.
  portrait9By16,
}

/// Embedded picker UI customization available on U SDK Extension 23+.
class EmbeddedPhotoPickerUiOptions {
  /// Creates embedded-specific UI settings.
  const EmbeddedPhotoPickerUiOptions({
    this.gridAspectRatio = EmbeddedPhotoPickerGridAspectRatio.systemDefault,
    this.selectionBarVisibleInExpandedMode = true,
  });

  /// The aspect ratio used for media grid thumbnails.
  final EmbeddedPhotoPickerGridAspectRatio gridAspectRatio;

  /// Whether the selection bar is visible while the picker is expanded.
  final bool selectionBarVisibleInExpandedMode;

  /// Encodes UI settings for the Android view.
  Map<String, Object?> toMap() => {
    'gridAspectRatio': gridAspectRatio.name,
    'selectionBarVisibleInExpandedMode': selectionBarVisibleInExpandedMode,
  };
}

/// Initial navigation and highlighted-content settings.
///
/// Album and search highlights require U SDK Extension 19. Expanded highlight
/// presentation requires Extension 21. [launchTab] and
/// [collapsedModeScrollingEnabled] require Extension 23.
class EmbeddedPhotoPickerNavigationOptions {
  /// Creates navigation settings, rejecting conflicting or empty highlights.
  EmbeddedPhotoPickerNavigationOptions({
    this.launchTab,
    this.highlightAlbum,
    this.highlightSearchQuery,
    this.highlightType = EmbeddedPhotoPickerHighlightType.collapsed,
    this.collapsedModeScrollingEnabled,
  }) {
    if (highlightAlbum != null && highlightSearchQuery != null) {
      throw ArgumentError(
        'Only one of highlightAlbum or highlightSearchQuery may be set',
      );
    }
    if (highlightSearchQuery != null && highlightSearchQuery!.trim().isEmpty) {
      throw ArgumentError.value(
        highlightSearchQuery,
        'highlightSearchQuery',
        'Must not be empty',
      );
    }
    if (highlightAlbum == null &&
        highlightSearchQuery == null &&
        highlightType != EmbeddedPhotoPickerHighlightType.collapsed) {
      throw ArgumentError('A highlight source is required for highlightType');
    }
  }

  /// The tab shown when the picker first opens, or `null` for Android's default.
  final EmbeddedPhotoPickerLaunchTab? launchTab;

  /// A system collection to highlight.
  final EmbeddedPhotoPickerHighlightAlbum? highlightAlbum;

  /// A text query whose matching media should be highlighted.
  final String? highlightSearchQuery;

  /// Whether highlights appear as a section or a full results grid.
  final EmbeddedPhotoPickerHighlightType highlightType;

  /// Whether the collapsed picker can scroll, or `null` for Android's default.
  final bool? collapsedModeScrollingEnabled;

  /// Encodes navigation settings for the Android view.
  Map<String, Object?> toMap() => {
    'launchTab': launchTab?.name,
    'highlightAlbum': highlightAlbum?.name,
    'highlightSearchQuery': highlightSearchQuery,
    'highlightType': highlightType.name,
    'collapsedModeScrollingEnabled': collapsedModeScrollingEnabled,
  };
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
    this.navigation,
    this.requestLocationMetadata = false,
    this.ui,
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

  /// Initial tab, highlighted content, and collapsed scrolling settings.
  final EmbeddedPhotoPickerNavigationOptions? navigation;

  /// Whether to ask the user to share location metadata for selected media.
  ///
  /// This requires Android 17.1 or U SDK Extension 23 and does not guarantee
  /// access. Android may ask the user, whose choice is final. The default is
  /// `false`, so location metadata remains redacted.
  final bool requestLocationMetadata;

  /// Embedded-specific grid and selection-bar appearance settings.
  final EmbeddedPhotoPickerUiOptions? ui;

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
    'navigation': navigation?.toMap(),
    'requestLocationMetadata': requestLocationMetadata,
    'ui': ui?.toMap(),
  };
}
