import 'package:embedded_photo_picker/embedded_photo_picker.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('embedded_photo_picker/media');
  const media = PhotoPickerMedia();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final uri = Uri.parse('content://media/picker/1');
  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  test('loads PNG bytes with default and custom dimensions', () async {
    final calls = <MethodCall>[];
    final bytes = Uint8List.fromList([1, 2, 3]);
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return bytes;
    });
    expect(await media.loadThumbnail(uri), bytes);
    expect(calls.single.method, 'loadThumbnail');
    expect(calls.single.arguments, {
      'uri': uri.toString(),
      'width': 384,
      'height': 384,
    });
    await media.loadThumbnail(uri, width: 128, height: 256);
    expect(calls.last.arguments, {
      'uri': uri.toString(),
      'width': 128,
      'height': 256,
    });
  });

  test('rejects invalid URIs and out-of-range dimensions', () async {
    await expectLater(
      media.loadThumbnail(Uri.parse('file:///photo.png')),
      throwsArgumentError,
    );
    await expectLater(
      media.loadThumbnail(Uri.parse('content:///photo')),
      throwsArgumentError,
    );
    for (final dimension in [0, -1, 1025]) {
      await expectLater(
        media.loadThumbnail(uri, width: dimension),
        throwsRangeError,
      );
      await expectLater(
        media.loadThumbnail(uri, height: dimension),
        throwsRangeError,
      );
    }
  });

  test('reports empty results and preserves platform errors', () async {
    for (final bytes in [null, Uint8List(0)]) {
      messenger.setMockMethodCallHandler(channel, (_) async => bytes);
      await expectLater(
        media.loadThumbnail(uri),
        throwsA(isA<PlatformException>()),
      );
    }
    messenger.setMockMethodCallHandler(channel, (_) async {
      throw PlatformException(code: 'thumbnail_unavailable');
    });
    await expectLater(
      media.loadThumbnail(uri),
      throwsA(
        isA<PlatformException>().having(
          (error) => error.code,
          'code',
          'thumbnail_unavailable',
        ),
      ),
    );
  });
}
