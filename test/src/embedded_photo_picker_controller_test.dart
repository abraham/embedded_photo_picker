import 'package:embedded_photo_picker/src/picker_config.dart';
import 'package:embedded_photo_picker/src/picker_platform.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  const channel = MethodChannel('embedded_photo_picker/view/7');
  late NativePickerController controller;
  late List<Object> events;

  setUp(() {
    events = [];
    controller = NativePickerController(
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
    'support is guarded on unsupported platforms and missing plugins',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      expect(
        (await PickerPlatform.checkSupport(PickerConfig.defaults)).isSupported,
        isFalse,
      );
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      expect(
        (await PickerPlatform.checkSupport(PickerConfig.defaults)).isSupported,
        isFalse,
      );
      messenger.setMockMethodCallHandler(
        const MethodChannel('embedded_photo_picker'),
        (call) async => {
          'available': true,
          'androidApiLevel': 37,
          'uExtensionVersion': 23,
        },
      );
      expect(
        (await PickerPlatform.checkSupport(PickerConfig.defaults)).isSupported,
        isTrue,
      );
    },
  );

  test('reports optional Android capabilities', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    expect(
      (await PickerPlatform.checkSupport(PickerConfig.defaults)).available,
      isFalse,
    );
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    expect(
      (await PickerPlatform.checkSupport(PickerConfig.defaults)).available,
      isFalse,
    );
    messenger.setMockMethodCallHandler(
      const MethodChannel('embedded_photo_picker'),
      (call) async => {
        'available': true,
        'androidApiLevel': 34,
        'uExtensionVersion': 22,
        'supportsHighlights': true,
        'supportsInitialExpandedState': true,
        'supportsSelectionConstraints': true,
        'supportsLaunchTab': false,
        'supportsLocationMetadata': false,
        'supportsCollapsedModeScrolling': false,
        'supportsEmbeddedUiCustomization': false,
      },
    );

    final config = PickerConfig(
      presentation: const PickerPresentation(initialTab: PickerTab.photos),
    );
    final support = await PickerPlatform.checkSupport(config);
    expect(support.available, isTrue);
    expect(support.androidApiLevel, 34);
    expect(support.uExtensionVersion, 22);
    expect(support.supports(PickerFeature.selectionConstraints), isTrue);
    expect(support.supports(PickerFeature.launchTab), isFalse);
    expect(support.unsupportedFeatures, {PickerFeature.launchTab});
  });

  test(
    'commands preserve URI identity and do not synthesize revoke events',
    () async {
      final calls = <MethodCall>[];
      messenger.setMockMethodCallHandler(channel, (call) async {
        calls.add(call);
        return null;
      });
      await controller.connect();
      await controller.setExpanded(true);
      await controller.setVisible(false);
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
      expect(() => controller.setVisible(true), throwsStateError);
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
