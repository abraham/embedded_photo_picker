import 'package:flutter/widgets.dart';

import 'picker_config.dart';

Map<String, Object?> encodePickerConfig(
  PickerConfig config,
  List<Uri> selection,
) {
  if (selection.length > config.maxSelection ||
      selection.toSet().length != selection.length) {
    throw ArgumentError(
      'Selection must be unique and within the configured limit',
    );
  }
  for (final uri in selection) {
    if (uri.scheme != 'content' || uri.authority.isEmpty) {
      throw ArgumentError.value(uri, 'selection', 'Expected content URI');
    }
  }

  final constraints = config.constraints;
  final hasConstraints =
      constraints != null &&
      (constraints.minResolutionPixels != null ||
          constraints.maxResolutionPixels != null ||
          constraints.maxFileSizeBytes != null ||
          constraints.maxTotalSizeBytes != null ||
          constraints.minVideoDuration != null ||
          constraints.maxVideoDuration != null ||
          constraints.allowedMimeTypes.isNotEmpty);
  final presentation = config.presentation;
  final highlight = presentation?.highlight;
  final hasNavigation =
      presentation?.initialTab != null ||
      highlight != null ||
      presentation?.collapsedScrolling != null;
  final hasUi =
      presentation?.gridAspectRatio != null ||
      presentation?.showSelectionBar != null;

  return {
    'maxSelection': config.maxSelection,
    'mimeTypes': config.filter.mimeTypes,
    'preselectedUris': selection.map((uri) => uri.toString()).toList(),
    'accentColor': config.accentColor?.withValues(alpha: 1).toARGB32(),
    'themeNightMode': switch (config.brightness) {
      Brightness.light => 0x10,
      Brightness.dark => 0x20,
      null => 0,
    },
    'orderedSelection': config.ordered,
    'selection': !hasConstraints
        ? null
        : {
            'minMediaItemResolutionInPixels': constraints.minResolutionPixels,
            'maxMediaItemResolutionInPixels': constraints.maxResolutionPixels,
            'maxMediaItemSizeInBytes': constraints.maxFileSizeBytes,
            'maxSelectionBatchSizeInBytes': constraints.maxTotalSizeBytes,
            'minVideoDurationMillis':
                constraints.minVideoDuration?.inMilliseconds,
            'maxVideoDurationMillis':
                constraints.maxVideoDuration?.inMilliseconds,
            'mimeTypes': constraints.allowedMimeTypes,
          },
    'navigation': hasNavigation
        ? {
            'launchTab': presentation?.initialTab?.name,
            'highlightAlbum': highlight?.album?.name,
            'highlightSearchQuery': highlight?.query,
            'highlightType': switch (highlight?.style) {
              PickerHighlightStyle.section => 'collapsed',
              PickerHighlightStyle.expanded => 'expanded',
              null => 'collapsed',
            },
            'collapsedModeScrollingEnabled': presentation?.collapsedScrolling,
          }
        : null,
    'requestLocationMetadata':
        config.locationMetadata == PickerLocationMetadata.request,
    'ui': hasUi
        ? {
            'gridAspectRatio': presentation?.gridAspectRatio?.name,
            'selectionBarVisibleInExpandedMode': presentation?.showSelectionBar,
          }
        : null,
  };
}
