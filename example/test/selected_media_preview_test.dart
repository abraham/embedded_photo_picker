import 'dart:async';
import 'dart:ui' as ui;

import 'package:embedded_photo_picker_example/selected_media_preview.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('embedded_photo_picker/media');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final uri = Uri.parse('content://media/picker/1');
  late Uint8List imageBytes;

  setUpAll(() async {
    final recorder = ui.PictureRecorder();
    ui.Canvas(recorder).drawColor(Colors.teal, BlendMode.src);
    final picture = recorder.endRecording();
    final image = await picture.toImage(8, 8);
    imageBytes = (await image.toByteData(format: ui.ImageByteFormat.png))!
        .buffer
        .asUint8List();
    image.dispose();
    picture.dispose();
  });
  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  Widget preview({VoidCallback? onRemove, Uri? selectedUri}) => MaterialApp(
    home: Scaffold(
      body: SizedBox.square(
        dimension: 120,
        child: SelectedMediaPreview(
          uri: selectedUri ?? uri,
          onRemove: onRemove ?? () {},
        ),
      ),
    ),
  );

  testWidgets('loads once and displays an image instead of its URI', (
    tester,
  ) async {
    var requests = 0;
    messenger.setMockMethodCallHandler(channel, (_) async {
      requests++;
      return imageBytes;
    });
    var removed = false;
    await tester.pumpWidget(preview(onRemove: () => removed = true));
    await tester.pumpAndSettle();
    expect(find.byType(Image), findsOneWidget);
    expect(tester.widget<Image>(find.byType(Image)).fit, BoxFit.contain);
    expect(find.text(uri.toString()), findsNothing);
    await tester.pumpWidget(preview(onRemove: () => removed = true));
    await tester.pumpAndSettle();
    expect(requests, 1);
    await tester.tap(find.byTooltip('Remove attachment'));
    expect(removed, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('keeps removal available while loading and after failure', (
    tester,
  ) async {
    final pending = Completer<Uint8List>();
    messenger.setMockMethodCallHandler(channel, (_) => pending.future);
    var removed = false;
    await tester.pumpWidget(preview(onRemove: () => removed = true));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await tester.tap(find.byTooltip('Remove attachment'));
    expect(removed, isTrue);
    pending.completeError(PlatformException(code: 'thumbnail_unavailable'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Preview unavailable'), findsOneWidget);
    expect(find.byTooltip('Remove attachment'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('reloads changed URIs and ignores completion after disposal', (
    tester,
  ) async {
    final requests = <String>[];
    final pending = Completer<Uint8List>();
    messenger.setMockMethodCallHandler(channel, (call) {
      requests.add((call.arguments as Map)['uri'] as String);
      return requests.length == 1 ? Future.value(imageBytes) : pending.future;
    });
    await tester.pumpWidget(preview());
    await tester.pumpAndSettle();
    final otherUri = Uri.parse('content://media/picker/2');
    await tester.pumpWidget(preview(selectedUri: otherUri));
    expect(requests, [uri.toString(), otherUri.toString()]);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    pending.complete(imageBytes);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
