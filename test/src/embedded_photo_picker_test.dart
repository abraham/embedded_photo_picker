import 'dart:async';

import 'package:embedded_photo_picker/embedded_photo_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  const pluginChannel = MethodChannel('embedded_photo_picker');

  Map<String, Object> capabilities({
    bool available = true,
    bool allFeatures = true,
  }) => {
    'available': available,
    'androidApiLevel': available ? 37 : 0,
    'uExtensionVersion': available ? 23 : 0,
    'supportsHighlights': allFeatures,
    'supportsInitialExpandedState': allFeatures,
    'supportsSelectionConstraints': allFeatures,
    'supportsLaunchTab': allFeatures,
    'supportsLocationMetadata': allFeatures,
    'supportsCollapsedModeScrolling': allFeatures,
    'supportsEmbeddedUiCustomization': allFeatures,
  };

  Widget picker({
    List<Uri> selection = const [],
    ValueChanged<PickerSelectionChange>? onChanged,
    ValueChanged<PlatformException>? onError,
    PickerConfig config = PickerConfig.defaults,
  }) => Directionality(
    textDirection: TextDirection.ltr,
    child: SizedBox(
      width: 400,
      height: 400,
      child: EmbeddedPhotoPicker(
        selection: selection,
        config: config,
        onChanged: onChanged ?? (_) {},
        onError: onError,
        loadingBuilder: (_) => const Text('Loading'),
        fallbackBuilder: (_) => const Text('Unavailable'),
      ),
    ),
  );

  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    messenger.setMockMethodCallHandler(pluginChannel, null);
    messenger.setMockMethodCallHandler(SystemChannels.platform_views, null);
  });

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
    messenger.setMockMethodCallHandler(
      pluginChannel,
      (_) async => capabilities(available: false, allFeatures: false),
    );
    await tester.pumpWidget(picker());
    await tester.pumpAndSettle();
    expect(find.text('Unavailable'), findsOneWidget);
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('preflights configured features before creating a native view', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    messenger.setMockMethodCallHandler(
      pluginChannel,
      (_) async => capabilities(allFeatures: false),
    );
    final errors = <PlatformException>[];
    await tester.pumpWidget(
      picker(
        config: PickerConfig(
          presentation: const PickerPresentation(
            initialTab: PickerTab.collections,
          ),
        ),
        onError: errors.add,
      ),
    );
    await tester.pumpAndSettle();

    expect(errors.single.code, 'unsupported_feature');
    expect(find.text('Unavailable'), findsOneWidget);
    expect(find.byType(PlatformViewLink), findsNothing);
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('rejects expanded highlights on a collapsed widget', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    final errors = <PlatformException>[];
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: EmbeddedPhotoPicker(
          selection: const [],
          config: PickerConfig(
            presentation: const PickerPresentation(
              highlight: PickerHighlight.album(
                PickerAlbum.favorites,
                style: PickerHighlightStyle.expanded,
              ),
            ),
          ),
          expanded: false,
          onChanged: (_) {},
          onError: errors.add,
          fallbackBuilder: (_) => const Text('Unavailable'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(errors.single.code, 'invalid_configuration');
    expect(find.text('Unavailable'), findsOneWidget);
    expect(find.byType(PlatformViewLink), findsNothing);
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('reports support lookup failures and displays fallback', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    final errors = <PlatformException>[];
    messenger.setMockMethodCallHandler(pluginChannel, (_) async {
      throw PlatformException(code: 'unavailable');
    });
    await tester.pumpWidget(picker(onError: errors.add));
    await tester.pumpAndSettle();
    expect(errors.single.code, 'unavailable');
    expect(find.text('Unavailable'), findsOneWidget);
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('reports snapshots, completion, and host-driven deselection', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    messenger.setMockMethodCallHandler(
      pluginChannel,
      (_) async => capabilities(),
    );
    final commands = <MethodCall>[];
    final changes = <PickerSelectionChange>[];
    final completions = <List<Uri>>[];
    MethodChannel? viewChannel;
    late StateSetter updateHost;
    var selection = <Uri>[];
    var ready = false;

    messenger.setMockMethodCallHandler(SystemChannels.platform_views, (
      call,
    ) async {
      if (call.method == 'create') {
        final arguments = call.arguments as Map;
        expect(arguments['hybrid'], isTrue);
        final params = const StandardMessageCodec().decodeMessage(
          ByteData.sublistView(arguments['params'] as Uint8List),
        ) as Map;
        expect(params['initialExpanded'], isFalse);
        expect(
          params['preselectedUris'],
          selection.map((uri) => uri.toString()).toList(),
        );
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
      StatefulBuilder(
        builder: (context, setState) {
          updateHost = setState;
          return Directionality(
            textDirection: TextDirection.ltr,
            child: SizedBox(
              width: 400,
              height: 400,
              child: EmbeddedPhotoPicker(
                selection: selection,
                config: PickerConfig(maxSelection: 3),
                expanded: false,
                onReady: () => ready = true,
                onChanged: (change) {
                  changes.add(change);
                  setState(() => selection = change.selection);
                },
                onDone: completions.add,
                fallbackBuilder: (_) => const Text('Failed picker'),
              ),
            ),
          );
        },
      ),
    );
    await tester.pumpAndSettle();
    expect(commands.single.method, 'connect');

    await event('ready');
    await tester.pumpAndSettle();
    expect(ready, isTrue);
    expect(commands.map((call) => call.method), [
      'connect',
      'setExpanded',
      'setVisible',
    ]);

    final first = Uri.parse('content://media/1');
    final second = Uri.parse('content://media/2');
    await event('granted', [first.toString(), second.toString()]);
    await tester.pumpAndSettle();
    expect(changes.single.selection, [first, second]);
    expect(changes.single.added, [first, second]);

    updateHost(() => selection = [second]);
    await tester.pumpAndSettle();
    expect(commands.last.method, 'deselect');
    expect(commands.last.arguments, [first.toString()]);

    await event('revoked', [second.toString()]);
    await tester.pumpAndSettle();
    expect(changes.last.selection, isEmpty);
    expect(changes.last.removed, [second]);

    await event('complete');
    expect(completions.single, isEmpty);
    messenger.setMockMethodCallHandler(viewChannel!, null);
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('remounts for config changes and external additions', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    messenger.setMockMethodCallHandler(
      pluginChannel,
      (_) async => capabilities(),
    );
    final creationParams = <Map>[];
    late StateSetter updateHost;
    var config = PickerConfig.defaults;
    var selection = <Uri>[];
    messenger.setMockMethodCallHandler(SystemChannels.platform_views, (
      call,
    ) async {
      if (call.method == 'create') {
        final arguments = call.arguments as Map;
        creationParams.add(
          const StandardMessageCodec().decodeMessage(
            ByteData.sublistView(arguments['params'] as Uint8List),
          ) as Map,
        );
        final viewChannel = MethodChannel(
          'embedded_photo_picker/view/${arguments['id']}',
        );
        messenger.setMockMethodCallHandler(viewChannel, (_) async => null);
      }
      return null;
    });

    await tester.pumpWidget(
      StatefulBuilder(
        builder: (context, setState) {
          updateHost = setState;
          return picker(selection: selection, config: config);
        },
      ),
    );
    await tester.pumpAndSettle();
    expect(creationParams, hasLength(1));

    updateHost(() => config = PickerConfig(maxSelection: 2));
    await tester.pumpAndSettle();
    expect(creationParams, hasLength(2));
    expect(creationParams.last['maxSelection'], 2);

    final uri = Uri.parse('content://media/1');
    updateHost(() => selection = [uri]);
    await tester.pumpAndSettle();
    expect(creationParams, hasLength(3));
    expect(creationParams.last['preselectedUris'], [uri.toString()]);
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('ignores support completion after unmount', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    final support = Completer<Map<String, Object>>();
    messenger.setMockMethodCallHandler(pluginChannel, (_) => support.future);
    await tester.pumpWidget(picker());
    expect(find.text('Loading'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    support.complete(capabilities());
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    debugDefaultTargetPlatformOverride = null;
  });
}
