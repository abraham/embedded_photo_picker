import 'package:embedded_photo_picker/embedded_photo_picker.dart';

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  const channel = MethodChannel('embedded_photo_picker');

  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    messenger.setMockMethodCallHandler(channel, null);
    messenger.setMockMethodCallHandler(SystemChannels.platform_views, null);
  });

  Widget picker({ValueChanged<PlatformException>? onError}) => Directionality(
    textDirection: TextDirection.ltr,
    child: SizedBox(
      width: 400,
      height: 400,
      child: EmbeddedPhotoPicker(
        options: EmbeddedPhotoPickerOptions(),
        onUrisGranted: (_) {},
        onUrisRevoked: (_) {},
        onSelectionComplete: () {},
        onError: onError,
        loadingBuilder: (_) => const Text('Loading'),
        fallbackBuilder: (_) => const Text('Unavailable'),
      ),
    ),
  );

  testWidgets('renders fallback without platform calls on non-Android', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    await tester.pumpWidget(picker());
    await tester.pumpAndSettle();
    expect(find.text('Unavailable'), findsOneWidget);
    expect(find.byType(PlatformViewLink), findsNothing);
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('renders fallback when Android capability is absent', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    messenger.setMockMethodCallHandler(channel, (_) async => false);
    await tester.pumpWidget(picker());
    await tester.pumpAndSettle();
    expect(find.text('Unavailable'), findsOneWidget);
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('reports availability failures and displays fallback', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    final errors = <PlatformException>[];
    messenger.setMockMethodCallHandler(channel, (_) async {
      throw PlatformException(code: 'unavailable');
    });
    await tester.pumpWidget(picker(onError: errors.add));
    await tester.pumpAndSettle();
    expect(errors.single.code, 'unavailable');
    expect(find.text('Unavailable'), findsOneWidget);
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('creates hybrid view, delivers events, and disposes on failure', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    messenger.setMockMethodCallHandler(channel, (_) async => true);
    final platformCalls = <MethodCall>[];
    final commands = <MethodCall>[];
    final events = <Object>[];
    MethodChannel? viewChannel;
    EmbeddedPhotoPickerController? readyController;
    messenger.setMockMethodCallHandler(SystemChannels.platform_views, (
      call,
    ) async {
      platformCalls.add(call);
      if (call.method == 'create') {
        final arguments = call.arguments as Map;
        expect(arguments['hybrid'], isTrue);
        viewChannel = MethodChannel(
          'embedded_photo_picker/view/${arguments['id']}',
        );
        messenger.setMockMethodCallHandler(viewChannel!, (command) async {
          commands.add(command);
          return null;
        });
      }
      return null;
    });
    Future<void> event(String method, [Object? arguments]) =>
        messenger.handlePlatformMessage(
          viewChannel!.name,
          const StandardMethodCodec().encodeMethodCall(
            MethodCall(method, arguments),
          ),
          (_) {},
        );

    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: SizedBox(
          width: 400,
          height: 400,
          child: EmbeddedPhotoPicker(
            options: EmbeddedPhotoPickerOptions(maxSelection: 3),
            onReady: (controller) => readyController = controller,
            onUrisGranted: events.add,
            onUrisRevoked: events.add,
            onSelectionComplete: () => events.add('complete'),
            onError: events.add,
            fallbackBuilder: (_) => const Text('Failed picker'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(commands.single.method, 'connect');
    await event('ready');
    await tester.pumpAndSettle();
    expect(readyController, isNotNull);
    expect(commands.map((call) => call.method), [
      'connect',
      'setExpanded',
      'setVisible',
    ]);
    await event('granted', ['content://media/1']);
    await event('revoked', ['content://media/1']);
    await event('complete');
    expect(events, [
      [Uri.parse('content://media/1')],
      [Uri.parse('content://media/1')],
      'complete',
    ]);
    await event('error', {'code': 'session_error', 'message': 'Disconnected'});
    await tester.pumpAndSettle();
    expect(find.text('Failed picker'), findsOneWidget);
    expect(platformCalls.last.method, 'dispose');
    expect(() => readyController!.setVisible(visible: true), throwsStateError);
    messenger.setMockMethodCallHandler(viewChannel!, null);
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('ignores availability completion after unmount', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    final availability = Completer<bool>();
    messenger.setMockMethodCallHandler(channel, (_) => availability.future);
    await tester.pumpWidget(picker());
    expect(find.text('Loading'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    availability.complete(true);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    debugDefaultTargetPlatformOverride = null;
  });
}
