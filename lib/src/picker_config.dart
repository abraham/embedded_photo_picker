import 'package:flutter/foundation.dart';
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

/// Optional Android features that can be checked before mounting a picker.
enum PickerFeature {
  /// Album and text-query highlights.
  highlights,

  /// Declaring the initial expanded state and expanded highlights.
  initialExpandedState,

  /// Resolution, file-size, duration, and selectable MIME constraints.
  selectionConstraints,

  /// Choosing the initial Photos or Collections tab.
  launchTab,

  /// Requesting selected-media location metadata.
  locationMetadata,

  /// Scrolling while the picker is collapsed.
  collapsedModeScrolling,

  /// Embedded grid and selection-bar customization.
  embeddedUiCustomization,
}

/// Media hidden from the picker before selection.
@immutable
class PickerFilter {
  const PickerFilter._(this.mimeTypes);

  /// Shows all supported images and videos.
  static const all = PickerFilter._(<String>[]);

  /// Shows images only.
  static const images = PickerFilter._(<String>['image/*']);

  /// Shows videos only.
  static const videos = PickerFilter._(<String>['video/*']);

  /// Shows only media matching [mimeTypes].
  factory PickerFilter.mimeTypes(List<String> mimeTypes) {
    if (mimeTypes.isEmpty) {
      throw ArgumentError.value(mimeTypes, 'mimeTypes', 'Must not be empty');
    }
    _validateMimeTypes(mimeTypes, 'mimeTypes');
    return PickerFilter._(List.unmodifiable(mimeTypes));
  }

  /// MIME types sent to Android, or an empty list for all media.
  final List<String> mimeTypes;

  @override
  bool operator ==(Object other) =>
      other is PickerFilter && listEquals(other.mimeTypes, mimeTypes);

  @override
  int get hashCode => Object.hashAll(mimeTypes);
}

/// Constraints that leave unmatched media visible but unavailable to select.
@immutable
class PickerConstraints {
  /// Creates constraints and rejects invalid ranges or MIME types.
  PickerConstraints({
    this.minResolutionPixels,
    this.maxResolutionPixels,
    this.maxFileSizeBytes,
    this.maxTotalSizeBytes,
    this.minVideoDuration,
    this.maxVideoDuration,
    List<String> allowedMimeTypes = const [],
  }) : allowedMimeTypes = List.unmodifiable(allowedMimeTypes) {
    _checkPositive(minResolutionPixels, 'minResolutionPixels');
    _checkPositive(maxResolutionPixels, 'maxResolutionPixels');
    _checkPositive(maxFileSizeBytes, 'maxFileSizeBytes');
    _checkPositive(maxTotalSizeBytes, 'maxTotalSizeBytes');
    if (minResolutionPixels != null &&
        maxResolutionPixels != null &&
        minResolutionPixels! > maxResolutionPixels!) {
      throw ArgumentError('Minimum resolution cannot exceed the maximum');
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
    _validateMimeTypes(this.allowedMimeTypes, 'allowedMimeTypes');
  }

  /// The minimum total pixel count for a selectable media item.
  final int? minResolutionPixels;

  /// The maximum total pixel count for a selectable media item.
  final int? maxResolutionPixels;

  /// The maximum size of an individual selectable item.
  final int? maxFileSizeBytes;

  /// The maximum cumulative size of all selected items.
  final int? maxTotalSizeBytes;

  /// The minimum selectable video duration.
  final Duration? minVideoDuration;

  /// The maximum selectable video duration.
  final Duration? maxVideoDuration;

  /// MIME types allowed for selection, or empty for all visible media.
  final List<String> allowedMimeTypes;

  @override
  bool operator ==(Object other) =>
      other is PickerConstraints &&
      other.minResolutionPixels == minResolutionPixels &&
      other.maxResolutionPixels == maxResolutionPixels &&
      other.maxFileSizeBytes == maxFileSizeBytes &&
      other.maxTotalSizeBytes == maxTotalSizeBytes &&
      other.minVideoDuration == minVideoDuration &&
      other.maxVideoDuration == maxVideoDuration &&
      listEquals(other.allowedMimeTypes, allowedMimeTypes);

  @override
  int get hashCode => Object.hash(
    minResolutionPixels,
    maxResolutionPixels,
    maxFileSizeBytes,
    maxTotalSizeBytes,
    minVideoDuration,
    maxVideoDuration,
    Object.hashAll(allowedMimeTypes),
  );
}

/// The tab displayed when the picker first opens.
enum PickerTab {
  /// The Photos tab.
  photos,

  /// The Collections tab.
  collections,
}

/// A system collection whose media can be highlighted.
enum PickerAlbum {
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

/// How highlighted media is presented.
enum PickerHighlightStyle {
  /// A highlighted section in the regular picker.
  section,

  /// A full highlighted-results grid.
  expanded,
}

/// A valid album or search highlight request.
@immutable
class PickerHighlight {
  const PickerHighlight._({this.album, this.query, required this.style});

  /// Highlights a system [album].
  const PickerHighlight.album(
    PickerAlbum album, {
    PickerHighlightStyle style = PickerHighlightStyle.section,
  }) : this._(album: album, style: style);

  /// Highlights media matching [query].
  factory PickerHighlight.search(
    String query, {
    PickerHighlightStyle style = PickerHighlightStyle.section,
  }) {
    if (query.trim().isEmpty) {
      throw ArgumentError.value(query, 'query', 'Must not be empty');
    }
    return PickerHighlight._(query: query, style: style);
  }

  /// The highlighted album, when this is an album request.
  final PickerAlbum? album;

  /// The highlighted search query, when this is a search request.
  final String? query;

  /// Whether Android shows a section or a full results grid.
  final PickerHighlightStyle style;

  @override
  bool operator ==(Object other) =>
      other is PickerHighlight &&
      other.album == album &&
      other.query == query &&
      other.style == style;

  @override
  int get hashCode => Object.hash(album, query, style);
}

/// Thumbnail aspect ratios supported by the embedded picker grid.
enum PickerGridAspectRatio {
  /// Android's default ratio.
  systemDefault,

  /// Square 1:1 thumbnails.
  square,

  /// Portrait 9:16 thumbnails.
  portrait9By16,
}

/// Initial navigation and appearance settings.
@immutable
class PickerPresentation {
  /// Creates optional navigation, highlight, and appearance settings.
  const PickerPresentation({
    this.initialTab,
    this.highlight,
    this.collapsedScrolling,
    this.gridAspectRatio,
    this.showSelectionBar,
  });

  /// The tab shown when the picker first opens.
  final PickerTab? initialTab;

  /// An album or search to highlight.
  final PickerHighlight? highlight;

  /// Whether the collapsed picker can scroll, or `null` for Android's default.
  final bool? collapsedScrolling;

  /// The media-grid thumbnail ratio, or `null` for Android's default.
  final PickerGridAspectRatio? gridAspectRatio;

  /// Whether the expanded selection bar is shown, or `null` for the default.
  final bool? showSelectionBar;

  @override
  bool operator ==(Object other) =>
      other is PickerPresentation &&
      other.initialTab == initialTab &&
      other.highlight == highlight &&
      other.collapsedScrolling == collapsedScrolling &&
      other.gridAspectRatio == gridAspectRatio &&
      other.showSelectionBar == showSelectionBar;

  @override
  int get hashCode => Object.hash(
    initialTab,
    highlight,
    collapsedScrolling,
    gridAspectRatio,
    showSelectionBar,
  );
}

/// Whether selected media should expose location metadata.
enum PickerLocationMetadata {
  /// Keep sensitive location metadata redacted.
  redacted,

  /// Ask the user to share location metadata where available.
  request,
}

/// Creation-time configuration for an [EmbeddedPhotoPicker].
@immutable
class PickerConfig {
  const PickerConfig._({
    required this.maxSelection,
    required this.filter,
    required this.ordered,
    required this.accentColor,
    required this.brightness,
    required this.constraints,
    required this.presentation,
    required this.locationMetadata,
  });

  /// Default single-selection configuration for all images and videos.
  static const defaults = PickerConfig._(
    maxSelection: 1,
    filter: PickerFilter.all,
    ordered: false,
    accentColor: null,
    brightness: null,
    constraints: null,
    presentation: null,
    locationMetadata: PickerLocationMetadata.redacted,
  );

  /// Creates picker configuration and validates limits and color values.
  factory PickerConfig({
    int maxSelection = 1,
    PickerFilter filter = PickerFilter.all,
    bool ordered = false,
    Color? accentColor,
    Brightness? brightness,
    PickerConstraints? constraints,
    PickerPresentation? presentation,
    PickerLocationMetadata locationMetadata = PickerLocationMetadata.redacted,
  }) {
    if (maxSelection < 1) {
      throw ArgumentError.value(
        maxSelection,
        'maxSelection',
        'Must be positive',
      );
    }
    final luminance = accentColor?.computeLuminance();
    if (luminance != null && (luminance < 0.05 || luminance > 0.9)) {
      throw ArgumentError.value(
        accentColor,
        'accentColor',
        'Invalid luminance',
      );
    }
    return PickerConfig._(
      maxSelection: maxSelection,
      filter: filter,
      ordered: ordered,
      accentColor: accentColor,
      brightness: brightness,
      constraints: constraints,
      presentation: presentation,
      locationMetadata: locationMetadata,
    );
  }

  /// Maximum number of selected items.
  final int maxSelection;

  /// Media hidden from the picker before selection.
  final PickerFilter filter;

  /// Whether Android displays selection order.
  final bool ordered;

  /// Primary picker color, or `null` for Android's default.
  final Color? accentColor;

  /// Picker brightness, or `null` to follow the device theme.
  final Brightness? brightness;

  /// Optional constraints that disable unsuitable visible media.
  final PickerConstraints? constraints;

  /// Optional navigation, highlight, and appearance settings.
  final PickerPresentation? presentation;

  /// Whether sensitive location metadata stays redacted or is requested.
  final PickerLocationMetadata locationMetadata;

  /// Optional Android features required by this configuration.
  Set<PickerFeature> get requiredFeatures {
    final features = <PickerFeature>{};
    final constraints = this.constraints;
    if (constraints != null &&
        (constraints.minResolutionPixels != null ||
            constraints.maxResolutionPixels != null ||
            constraints.maxFileSizeBytes != null ||
            constraints.maxTotalSizeBytes != null ||
            constraints.minVideoDuration != null ||
            constraints.maxVideoDuration != null ||
            constraints.allowedMimeTypes.isNotEmpty)) {
      features.add(PickerFeature.selectionConstraints);
    }
    final presentation = this.presentation;
    if (presentation?.highlight != null) {
      features.add(PickerFeature.highlights);
      if (presentation!.highlight!.style == PickerHighlightStyle.expanded) {
        features.add(PickerFeature.initialExpandedState);
      }
    }
    if (presentation?.initialTab != null) features.add(PickerFeature.launchTab);
    if (presentation?.collapsedScrolling != null) {
      features.add(PickerFeature.collapsedModeScrolling);
    }
    if (presentation?.gridAspectRatio != null ||
        presentation?.showSelectionBar != null) {
      features.add(PickerFeature.embeddedUiCustomization);
    }
    if (locationMetadata == PickerLocationMetadata.request) {
      features.add(PickerFeature.locationMetadata);
    }
    return Set.unmodifiable(features);
  }

  @override
  bool operator ==(Object other) =>
      other is PickerConfig &&
      other.maxSelection == maxSelection &&
      other.filter == filter &&
      other.ordered == ordered &&
      other.accentColor == accentColor &&
      other.brightness == brightness &&
      other.constraints == constraints &&
      other.presentation == presentation &&
      other.locationMetadata == locationMetadata;

  @override
  int get hashCode => Object.hash(
    maxSelection,
    filter,
    ordered,
    accentColor,
    brightness,
    constraints,
    presentation,
    locationMetadata,
  );
}
