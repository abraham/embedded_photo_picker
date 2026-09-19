import 'package:embedded_photo_picker/embedded_photo_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  const channel = MethodChannel('embedded_photo_picker/view/7');
  late EmbeddedPhotoPickerController controller;
  late List<Object> events;

  setUp(() {
    events = [];
    controller = EmbeddedPhotoPickerController(
      7,
      onReady: () => events.add('ready'),
      onGranted: events.add,
      onRevoked: events.add,
      onComplete: () => events.add('complete'),
      onError: events.add,
    );
  });
  tearDown(() {
    controller.dispose();
    debugDefaultTargetPlatformOverride = null;
    messenger.setMockMethodCallHandler(channel, null);
    messenger.setMockMethodCallHandler(
      const MethodChannel('embedded_photo_picker'),
      null,
    );
  });

  test(
    'availability is guarded on unsupported platforms and missing plugins',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      expect(await EmbeddedPhotoPickerController.isAvailable(), isFalse);
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      expect(await EmbeddedPhotoPickerController.isAvailable(), isFalse);
      messenger.setMockMethodCallHandler(
        const MethodChannel('embedded_photo_picker'),
        (call) async => true,
      );
      expect(await EmbeddedPhotoPickerController.isAvailable(), isTrue);
    },
  );

  test(
    'commands preserve URI identity and do not synthesize revoke events',
    () async {
      final calls = <MethodCall>[];
      messenger.setMockMethodCallHandler(channel, (call) async {
        calls.add(call);
        return null;
      });
      await controller.connect();
      await controller.setExpanded(expanded: true);
      await controller.setVisible(visible: false);
      await controller.deselect([Uri.parse('content://media/1')]);
      expect(calls.map((call) => call.method), [
        'connect',
        'setExpanded',
        'setVisible',
        'deselect',
      ]);
      expect(calls.last.arguments, ['content://media/1']);
      expect(events, isEmpty);
      expect(
        () => controller.deselect([Uri.file('/photo')]),
        throwsArgumentError,
      );
      controller.dispose();
      expect(() => controller.setVisible(visible: true), throwsStateError);
    },
  );

  test('delivers native session events and errors', () async {
    for (final call in [
      const MethodCall('ready'),
      const MethodCall('granted', ['content://media/1']),
      const MethodCall('revoked', ['content://media/1']),
      const MethodCall('complete'),
      const MethodCall('error', {
        'code': 'session_error',
        'message': 'Unavailable',
      }),
    ]) {
      await messenger.handlePlatformMessage(
        channel.name,
        const StandardMethodCodec().encodeMethodCall(call),
        (_) {},
      );
    }
    expect(events[0], 'ready');
    expect(events[1], [Uri.parse('content://media/1')]);
    expect(events[2], [Uri.parse('content://media/1')]);
    expect(events[3], 'complete');
    expect((events[4] as PlatformException).code, 'session_error');
  });
}
