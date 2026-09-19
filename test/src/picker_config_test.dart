import 'package:embedded_photo_picker/src/picker_codec.dart';
import 'package:embedded_photo_picker/src/picker_config.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('encodes the default configuration', () {
    expect(encodePickerConfig(PickerConfig.defaults, const []), {
      'maxSelection': 1,
      'mimeTypes': <String>[],
      'preselectedUris': <String>[],
      'accentColor': null,
      'themeNightMode': 0,
      'orderedSelection': false,
      'selection': null,
      'navigation': null,
      'requestLocationMetadata': false,
      'ui': null,
    });
  });

  test('encodes typed advanced configuration', () {
    final config = PickerConfig(
      maxSelection: 4,
      filter: PickerFilter.images,
      ordered: true,
      accentColor: const Color(0xff777777),
      brightness: Brightness.dark,
      constraints: PickerConstraints(
        maxFileSizeBytes: 1000,
        allowedMimeTypes: ['image/jpeg'],
      ),
      presentation: const PickerPresentation(
        initialTab: PickerTab.collections,
        highlight: PickerHighlight.album(
          PickerAlbum.favorites,
          style: PickerHighlightStyle.expanded,
        ),
        collapsedScrolling: true,
        gridAspectRatio: PickerGridAspectRatio.portrait9By16,
        showSelectionBar: false,
      ),
      locationMetadata: PickerLocationMetadata.request,
    );

    expect(
      encodePickerConfig(config, [Uri.parse('content://media/1')]),
      containsPair('preselectedUris', ['content://media/1']),
    );
    final encoded = encodePickerConfig(config, const []);
    expect(encoded['mimeTypes'], ['image/*']);
    expect(encoded['orderedSelection'], isTrue);
    expect(encoded['selection'], containsPair('maxMediaItemSizeInBytes', 1000));
    expect(encoded['navigation'], containsPair('launchTab', 'collections'));
    expect(encoded['navigation'], containsPair('highlightAlbum', 'favorites'));
    expect(encoded['navigation'], containsPair('highlightType', 'expanded'));
    expect(encoded['ui'], containsPair('gridAspectRatio', 'portrait9By16'));
    expect(
      encoded['ui'],
      containsPair('selectionBarVisibleInExpandedMode', false),
    );
    expect(encoded['requestLocationMetadata'], isTrue);
    expect(
      config.requiredFeatures,
      containsAll({
        PickerFeature.highlights,
        PickerFeature.initialExpandedState,
        PickerFeature.selectionConstraints,
        PickerFeature.launchTab,
        PickerFeature.locationMetadata,
        PickerFeature.collapsedModeScrolling,
        PickerFeature.embeddedUiCustomization,
      }),
    );
  });

  test('models valid highlights and rejects invalid values', () {
    expect(PickerHighlight.search('receipts').query, 'receipts');
    expect(() => PickerHighlight.search('   '), throwsArgumentError);
    expect(() => PickerConfig(maxSelection: 0), throwsArgumentError);
    expect(
      () => PickerConstraints(minResolutionPixels: 2, maxResolutionPixels: 1),
      throwsArgumentError,
    );
    expect(() => PickerFilter.mimeTypes(['text/plain']), throwsArgumentError);
    expect(
      PickerConfig(constraints: PickerConstraints()).requiredFeatures,
      isEmpty,
    );
    expect(
      encodePickerConfig(
        PickerConfig(constraints: PickerConstraints()),
        const [],
      )['selection'],
      isNull,
    );
  });

  test('compares equivalent immutable configurations by value', () {
    expect(
      PickerConfig(
        maxSelection: 4,
        filter: PickerFilter.mimeTypes(['image/jpeg']),
        presentation: const PickerPresentation(
          highlight: PickerHighlight.album(PickerAlbum.camera),
        ),
      ),
      PickerConfig(
        maxSelection: 4,
        filter: PickerFilter.mimeTypes(['image/jpeg']),
        presentation: const PickerPresentation(
          highlight: PickerHighlight.album(PickerAlbum.camera),
        ),
      ),
    );
  });
}
