import 'dart:async';
import 'dart:ui' as ui;

import 'package:embedded_photo_picker/embedded_photo_picker.dart';
import 'package:embedded_photo_picker_example/chat_example.dart';
import 'package:embedded_photo_picker_example/chat_message_bubble.dart';
import 'package:embedded_photo_picker_example/selected_media_preview.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  const pickerChannel = MethodChannel('embedded_photo_picker');
  const mediaChannel = MethodChannel('embedded_photo_picker/media');
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
  setUp(() {
    messenger.setMockMethodCallHandler(pickerChannel, (_) async => false);
    messenger.setMockMethodCallHandler(mediaChannel, (_) async {
      throw PlatformException(code: 'thumbnail_unavailable');
    });
  });
  tearDown(() {
    messenger.setMockMethodCallHandler(pickerChannel, null);
    messenger.setMockMethodCallHandler(mediaChannel, null);
  });

  testWidgets('chat sends text and toggles the docked picker', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: ChatExample()));
    await tester.pumpAndSettle();
    expect(find.text('Ice cream fans'), findsOneWidget);
    expect(find.byType(EmbeddedPhotoPicker), findsNothing);
    await tester.tap(find.byTooltip('Add photos'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<EmbeddedPhotoPicker>(find.byType(EmbeddedPhotoPicker))
          .expanded,
      isFalse,
    );
    expect(
      tester
          .widget<IconButton>(
            find.byWidgetPredicate(
              (widget) =>
                  widget is IconButton && widget.tooltip == 'Send message',
            ),
          )
          .onPressed,
      isNull,
    );
    expect(find.byTooltip('Expand photos'), findsNothing);
    await tester.tap(find.byType(TextField));
    await tester.enterText(find.byType(TextField), 'These tasty ones');
    await tester.pumpAndSettle();
    expect(find.byType(EmbeddedPhotoPicker), findsNothing);
    await tester.tap(find.byTooltip('Send message'));
    await tester.pumpAndSettle();
    expect(find.text('These tasty ones'), findsOneWidget);
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      isEmpty,
    );
    await tester.tap(find.byTooltip('Add photos'));
    await tester.pumpAndSettle();
    expect(find.byType(EmbeddedPhotoPicker), findsOneWidget);
    expect(
      tester
          .widget<EmbeddedPhotoPicker>(find.byType(EmbeddedPhotoPicker))
          .expanded,
      isFalse,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('chat slides the picker open without resizing its surface', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: ChatExample()));
    await tester.pumpAndSettle();
    final closedComposerTop = tester.getTopLeft(find.byType(TextField)).dy;
    expect(find.byType(EmbeddedPhotoPicker), findsNothing);
    await tester.tap(find.byTooltip('Add photos'));
    await tester.pump();
    await tester.pump();
    await tester.pump();
    final picker = find.byType(EmbeddedPhotoPicker);
    final initialTop = tester.getTopLeft(picker).dy;
    final surfaceSize = tester.getSize(picker);
    final frame = const Duration(milliseconds: 150);
    await tester.pump(frame);
    final halfwayTop = tester.getTopLeft(picker).dy;
    expect(halfwayTop, lessThan(initialTop));
    expect(tester.getSize(picker), surfaceSize);
    expect(
      tester.getTopLeft(find.byType(TextField)).dy,
      lessThan(closedComposerTop),
    );
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(picker).dy, lessThan(halfwayTop));
    expect(tester.getSize(picker), surfaceSize);
    await tester.tap(find.byTooltip('Close photos'));
    await tester.pumpAndSettle();
    expect(picker, findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('chat skips the reveal when animations are disabled', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(disableAnimations: true),
          child: ChatExample(),
        ),
      ),
    );
    await tester.tap(find.byTooltip('Add photos'));
    await tester.pumpAndSettle();
    final picker = find.byType(EmbeddedPhotoPicker);
    final animation =
        tester
                .widget<AnimatedBuilder>(
                  find
                      .ancestor(
                        of: picker,
                        matching: find.byType(AnimatedBuilder),
                      )
                      .first,
                )
                .animation
            as AnimationController;
    expect(animation.isCompleted, isTrue);
    expect(animation.isAnimating, isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('chat can close before availability completes and reopen', (
    tester,
  ) async {
    final availability = Completer<bool>();
    messenger.setMockMethodCallHandler(
      pickerChannel,
      (_) => availability.future,
    );
    await tester.pumpWidget(const MaterialApp(home: ChatExample()));
    await tester.tap(find.byTooltip('Add photos'));
    await tester.pump();
    await tester.tap(find.byTooltip('Close photos'));
    await tester.pump();
    expect(find.byType(EmbeddedPhotoPicker), findsNothing);
    availability.complete(false);
    await tester.pumpAndSettle();
    expect(find.byType(EmbeddedPhotoPicker), findsNothing);
    await tester.tap(find.byTooltip('Add photos'));
    await tester.pumpAndSettle();
    expect(find.text('Picker unavailable'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('chat sends photo previews and keeps continuous selection open', (
    tester,
  ) async {
    messenger.setMockMethodCallHandler(mediaChannel, (_) async => imageBytes);
    await tester.pumpWidget(const MaterialApp(home: ChatExample()));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Add photos'));
    await tester.pumpAndSettle();
    final picker = tester.widget<EmbeddedPhotoPicker>(
      find.byType(EmbeddedPhotoPicker),
    );
    picker.onUrisGranted([Uri.parse('content://media/1')]);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Send message'));
    await tester.pumpAndSettle();
    expect(find.byType(SelectedMediaPreview), findsNothing);
    expect(find.byType(EmbeddedPhotoPicker), findsOneWidget);
    final sent = tester
        .widgetList<ChatMessageBubble>(find.byType(ChatMessageBubble))
        .where((bubble) => bubble.images.isNotEmpty)
        .single;
    expect(sent.images.single, imageBytes);
    expect(sent.outgoing, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('failed image sends retain the draft and allow retry', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: ChatExample()));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Add photos'));
    await tester.pumpAndSettle();
    tester
        .widget<EmbeddedPhotoPicker>(find.byType(EmbeddedPhotoPicker))
        .onUrisGranted([Uri.parse('content://media/1')]);
    await tester.enterText(find.byType(TextField), 'Keep this draft');
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Send message'));
    await tester.pumpAndSettle();
    expect(find.text('Unable to load attachments'), findsOneWidget);
    expect(find.byType(SelectedMediaPreview), findsOneWidget);
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      'Keep this draft',
    );
    messenger.setMockMethodCallHandler(mediaChannel, (_) async => imageBytes);
    await tester.tap(find.byTooltip('Send message'));
    await tester.pumpAndSettle();
    expect(find.text('Unable to load attachments'), findsNothing);
    expect(find.byType(SelectedMediaPreview), findsNothing);
    expect(find.text('Keep this draft'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'chat selection removal and revocation stay in sync on small screens',
    (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(const MaterialApp(home: ChatExample()));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Add photos'));
      await tester.pumpAndSettle();
      final picker = tester.widget<EmbeddedPhotoPicker>(
        find.byType(EmbeddedPhotoPicker),
      );
      final first = Uri.parse('content://media/1');
      final second = Uri.parse('content://media/2');
      picker.onUrisGranted([first, second]);
      await tester.pumpAndSettle();
      expect(find.byType(SelectedMediaPreview), findsNWidgets(2));
      expect(tester.takeException(), isNull);
      await tester.tap(find.byType(TextField));
      tester.view.viewInsets = const FakeViewPadding(bottom: 280);
      addTearDown(tester.view.resetViewInsets);
      await tester.pumpAndSettle();
      expect(find.byType(EmbeddedPhotoPicker), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.tap(find.byTooltip('Remove attachment').first);
      await tester.pumpAndSettle();
      expect(find.byType(SelectedMediaPreview), findsOneWidget);
      picker.onUrisRevoked([second]);
      await tester.pumpAndSettle();
      expect(find.byType(SelectedMediaPreview), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
