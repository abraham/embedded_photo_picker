import 'package:embedded_photo_picker/embedded_photo_picker.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('encodes defaults', () {
    expect(EmbeddedPhotoPickerOptions().toMap(), {
      'maxSelection': 1,
      'mimeTypes': <String>[],
      'preselectedUris': <String>[],
      'accentColor': null,
      'themeNightMode': 0,
      'orderedSelection': false,
      'selection': null,
      'navigation': null,
      'requestLocationMetadata': false,
    });
  });

  test('copies lists and encodes supported settings', () {
    final filters = ['image/*', 'video/mp4'];
    final uris = [Uri.parse('content://media/1')];
    final options = EmbeddedPhotoPickerOptions(
      maxSelection: 3,
      mimeTypes: filters,
      preselectedUris: uris,
      accentColor: const Color(0x80777777),
      brightness: Brightness.dark,
      orderedSelection: true,
    );
    filters.clear();
    uris.clear();
    expect(options.toMap()['mimeTypes'], ['image/*', 'video/mp4']);
    expect(options.toMap()['preselectedUris'], ['content://media/1']);
    expect(options.toMap()['accentColor'], 0xff777777);
    expect(options.toMap()['themeNightMode'], 0x20);
    expect(options.toMap()['orderedSelection'], isTrue);
    expect(
      EmbeddedPhotoPickerOptions(requestLocationMetadata: true)
          .toMap()['requestLocationMetadata'],
      isTrue,
    );
    expect(() => options.mimeTypes.clear(), throwsUnsupportedError);
    expect(
      EmbeddedPhotoPickerOptions(brightness: Brightness.light)
          .toMap()['themeNightMode'],
      0x10,
    );
  });

  test('copies and encodes selection constraints', () {
    final mimeTypes = ['image/jpeg', 'video/mp4'];
    final selection = EmbeddedPhotoPickerSelectionOptions(
      minMediaItemResolutionInPixels: 1000000,
      maxMediaItemResolutionInPixels: 12000000,
      maxMediaItemSizeInBytes: 8000000,
      maxSelectionBatchSizeInBytes: 20000000,
      minVideoDuration: const Duration(seconds: 1),
      maxVideoDuration: const Duration(minutes: 2),
      mimeTypes: mimeTypes,
    );
    mimeTypes.clear();

    expect(selection.toMap(), {
      'minMediaItemResolutionInPixels': 1000000,
      'maxMediaItemResolutionInPixels': 12000000,
      'maxMediaItemSizeInBytes': 8000000,
      'maxSelectionBatchSizeInBytes': 20000000,
      'minVideoDurationMillis': 1000,
      'maxVideoDurationMillis': 120000,
      'mimeTypes': ['image/jpeg', 'video/mp4'],
    });
    expect(
      EmbeddedPhotoPickerOptions(selection: selection).toMap()['selection'],
      selection.toMap(),
    );
    expect(() => selection.mimeTypes.clear(), throwsUnsupportedError);
  });

  test('rejects invalid selection constraints', () {
    expect(
      () => EmbeddedPhotoPickerSelectionOptions(
        minMediaItemResolutionInPixels: 2,
        maxMediaItemResolutionInPixels: 1,
      ),
      throwsArgumentError,
    );
    expect(
      () => EmbeddedPhotoPickerSelectionOptions(maxMediaItemSizeInBytes: 0),
      throwsArgumentError,
    );
    expect(
      () =>
          EmbeddedPhotoPickerSelectionOptions(maxSelectionBatchSizeInBytes: -1),
      throwsArgumentError,
    );
    expect(
      () => EmbeddedPhotoPickerSelectionOptions(
        minVideoDuration: const Duration(seconds: 2),
        maxVideoDuration: const Duration(seconds: 1),
      ),
      throwsArgumentError,
    );
    expect(
      () => EmbeddedPhotoPickerSelectionOptions(
        minVideoDuration: const Duration(microseconds: 1),
      ),
      throwsArgumentError,
    );
    expect(
      () => EmbeddedPhotoPickerSelectionOptions(mimeTypes: ['text/plain']),
      throwsArgumentError,
    );
  });

  test('encodes navigation and discovery settings', () {
    final navigation = EmbeddedPhotoPickerNavigationOptions(
      launchTab: EmbeddedPhotoPickerLaunchTab.collections,
      highlightAlbum: EmbeddedPhotoPickerHighlightAlbum.favorites,
      highlightType: EmbeddedPhotoPickerHighlightType.expanded,
      collapsedModeScrollingEnabled: true,
    );

    expect(navigation.toMap(), {
      'launchTab': 'collections',
      'highlightAlbum': 'favorites',
      'highlightSearchQuery': null,
      'highlightType': 'expanded',
      'collapsedModeScrollingEnabled': true,
    });
    expect(
      EmbeddedPhotoPickerOptions(navigation: navigation).toMap()['navigation'],
      navigation.toMap(),
    );
    expect(
      EmbeddedPhotoPickerNavigationOptions(highlightSearchQuery: 'receipts')
          .toMap()['highlightSearchQuery'],
      'receipts',
    );
  });

  test('rejects invalid navigation settings', () {
    expect(
      () => EmbeddedPhotoPickerNavigationOptions(
        highlightAlbum: EmbeddedPhotoPickerHighlightAlbum.camera,
        highlightSearchQuery: 'vacation',
      ),
      throwsArgumentError,
    );
    expect(
      () => EmbeddedPhotoPickerNavigationOptions(highlightSearchQuery: '   '),
      throwsArgumentError,
    );
    expect(
      () => EmbeddedPhotoPickerNavigationOptions(
        highlightType: EmbeddedPhotoPickerHighlightType.expanded,
      ),
      throwsArgumentError,
    );
  });

  test('rejects invalid configuration in release builds too', () {
    expect(
      () => EmbeddedPhotoPickerOptions(maxSelection: 0),
      throwsArgumentError,
    );
    expect(
      () => EmbeddedPhotoPickerOptions(mimeTypes: ['text/plain']),
      throwsArgumentError,
    );
    expect(
      () =>
          EmbeddedPhotoPickerOptions(preselectedUris: [Uri.file('/tmp/photo')]),
      throwsArgumentError,
    );
    expect(
      () => EmbeddedPhotoPickerOptions(
        preselectedUris: [
          Uri.parse('content://media/1'),
          Uri.parse('content://media/2'),
        ],
      ),
      throwsArgumentError,
    );
    expect(
      () => EmbeddedPhotoPickerOptions(accentColor: const Color(0xff000000)),
      throwsArgumentError,
    );
  });
}
