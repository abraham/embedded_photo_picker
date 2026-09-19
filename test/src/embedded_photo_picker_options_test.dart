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
    expect(() => options.mimeTypes.clear(), throwsUnsupportedError);
    expect(
      EmbeddedPhotoPickerOptions(brightness: Brightness.light)
          .toMap()['themeNightMode'],
      0x10,
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
