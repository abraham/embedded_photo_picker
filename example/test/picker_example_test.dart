import 'dart:async';

import 'package:embedded_photo_picker/embedded_photo_picker.dart';
import 'package:embedded_photo_picker_example/picker_example.dart';
import 'package:embedded_photo_picker_example/selected_media_preview.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('embedded_photo_picker');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  setUp(() => messenger.setMockMethodCallHandler(channel, (_) async => false));
  tearDown(() => messenger.setMockMethodCallHandler(channel, null));
  testWidgets(
    'composer has five bordered lines and aligned gallery and post controls',
    (tester) async {
      await tester.pumpWidget(const MaterialApp(home: PickerExample()));
      await tester.pumpAndSettle();

      final message = tester.widget<TextField>(find.byType(TextField));
      expect(message.minLines, 5);
      expect(message.maxLines, 5);
      expect(message.keyboardType, TextInputType.multiline);
      expect(message.decoration!.border, isA<OutlineInputBorder>());

      expect(find.byType(EmbeddedPhotoPicker), findsNothing);
      final gallery = find.byTooltip('Open picker');
      final post = find.widgetWithText(FilledButton, 'Post');
      expect(tester.getCenter(gallery).dy, tester.getCenter(post).dy);
      expect(tester.getCenter(gallery).dx, lessThan(tester.getCenter(post).dx));
      expect(
        tester.getTopLeft(gallery).dy,
        greaterThan(tester.getBottomLeft(find.byType(TextField)).dy),
      );
      expect(tester.widget<FilledButton>(post).onPressed, isNull);
    },
  );

  testWidgets(
    'selected media uses previews and supports removal and revocation',
    (tester) async {
      const mediaChannel = MethodChannel('embedded_photo_picker/media');
      messenger.setMockMethodCallHandler(mediaChannel, (_) async {
        throw PlatformException(code: 'thumbnail_unavailable');
      });
      addTearDown(() => messenger.setMockMethodCallHandler(mediaChannel, null));
      await tester.pumpWidget(const MaterialApp(home: PickerExample()));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Open picker'));
      await tester.pumpAndSettle();
      final picker = tester.widget<EmbeddedPhotoPicker>(
        find.byType(EmbeddedPhotoPicker),
      );
      final firstUri = Uri.parse('content://media/picker/1');
      final secondUri = Uri.parse('content://media/picker/2');
      picker.onUrisGranted([firstUri, secondUri]);
      await tester.pumpAndSettle();
      expect(find.byType(SelectedMediaPreview), findsNWidgets(2));
      expect(find.text(firstUri.toString()), findsNothing);
      expect(find.text(secondUri.toString()), findsNothing);

      await tester.tap(find.byTooltip('Remove attachment').first);
      await tester.pumpAndSettle();
      expect(find.byType(SelectedMediaPreview), findsOneWidget);
      expect(
        tester
            .widget<SelectedMediaPreview>(find.byType(SelectedMediaPreview))
            .uri,
        secondUri,
      );
      picker.onUrisRevoked([secondUri]);
      await tester.pumpAndSettle();
      expect(find.byType(SelectedMediaPreview), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('selected previews scroll horizontally on a narrow screen', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    const mediaChannel = MethodChannel('embedded_photo_picker/media');
    messenger.setMockMethodCallHandler(mediaChannel, (_) async {
      throw PlatformException(code: 'thumbnail_unavailable');
    });
    addTearDown(() => messenger.setMockMethodCallHandler(mediaChannel, null));
    await tester.pumpWidget(const MaterialApp(home: PickerExample()));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Open picker'));
    await tester.pumpAndSettle();
    final uris = List.generate(
      4,
      (index) => Uri.parse('content://media/picker/$index'),
    );
    tester
        .widget<EmbeddedPhotoPicker>(find.byType(EmbeddedPhotoPicker))
        .onUrisGranted(uris);
    await tester.pumpAndSettle();
    final strip = find.byType(ListView);
    expect(tester.widget<ListView>(strip).scrollDirection, Axis.horizontal);
    expect(
      tester.getTopLeft(find.byKey(ValueKey(uris[0]))).dy,
      tester.getTopLeft(find.byKey(ValueKey(uris[1]))).dy,
    );
    await tester.drag(strip, const Offset(-300, 0));
    await tester.pumpAndSettle();
    final lastPreview = find.byKey(ValueKey(uris.last));
    expect(lastPreview.hitTestable(), findsOneWidget);
    expect(tester.getTopRight(lastPreview).dx, lessThanOrEqualTo(320));
    await tester.tap(
      find.descendant(
        of: lastPreview,
        matching: find.byTooltip('Remove attachment'),
      ),
    );
    await tester.pumpAndSettle();
    expect(lastPreview, findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('compose stays expanded in a small viewport after reopening', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const MaterialApp(home: PickerExample()));
    await tester.pumpAndSettle();
    final picker = find.byType(EmbeddedPhotoPicker);
    expect(picker, findsNothing);
    await tester.tap(find.byTooltip('Open picker'));
    await tester.pumpAndSettle();
    expect(find.byType(SegmentedButton<bool>), findsNothing);
    expect(tester.widget<EmbeddedPhotoPicker>(picker).expanded, isTrue);
    expect(tester.takeException(), isNull);

    await tester.tap(find.byTooltip('Close picker'));
    await tester.pumpAndSettle();
    expect(picker, findsNothing);
    await tester.tap(find.byTooltip('Open picker'));
    await tester.pumpAndSettle();
    expect(tester.widget<EmbeddedPhotoPicker>(picker).expanded, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('picker slides without resizing and reverses mid-transition', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: PickerExample()));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Open picker'));
    await tester.pumpAndSettle();
    final picker = find.byType(EmbeddedPhotoPicker);
    final originalState = tester.state(picker);
    final originalTop = tester.getTopLeft(picker).dy;
    final originalSize = tester.getSize(picker);
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

    await tester.tap(find.byTooltip('Close picker'));
    await tester.pump();
    await tester.pump(animation.duration! ~/ 2);
    expect(tester.getTopLeft(picker).dy, greaterThan(originalTop));
    expect(tester.getSize(picker), originalSize);
    expect(tester.state(picker), same(originalState));

    await tester.tap(find.byTooltip('Open picker'));
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(picker).dy, originalTop);
    expect(tester.state(picker), same(originalState));

    await tester.tap(find.byTooltip('Close picker'));
    await tester.pumpAndSettle();
    expect(picker, findsNothing);
    expect(find.byType(SegmentedButton<bool>), findsNothing);

    await tester.tap(find.byTooltip('Open picker'));
    await tester.pump();
    await tester.pump(animation.duration! ~/ 2);
    expect(tester.getTopLeft(picker).dy, greaterThan(originalTop));
    expect(tester.getSize(picker), originalSize);
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(picker).dy, originalTop);
    expect(tester.takeException(), isNull);
  });

  testWidgets('dragging the divider resizes without replacing the picker', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: PickerExample()));
    await tester.pumpAndSettle();
    final divider = find.bySemanticsLabel('Resize photo picker');
    expect(divider, findsNothing);
    await tester.tap(find.byTooltip('Open picker'));
    await tester.pumpAndSettle();
    final picker = find.byType(EmbeddedPhotoPicker);
    final pickerState = tester.state(picker);
    final initialHeight = tester.getSize(picker).height;
    expect(tester.getBottomLeft(divider).dy, tester.getTopLeft(picker).dy);
    final header = tester.widget<Material>(
      find.descendant(of: divider, matching: find.byType(Material)),
    );
    expect(
      header.shape,
      const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
    );
    expect(header.clipBehavior, Clip.antiAlias);
    expect(header.color, Colors.transparent);
    final decoration =
        tester
                .widget<DecoratedBox>(
                  find
                      .descendant(
                        of: divider,
                        matching: find.byType(DecoratedBox),
                      )
                      .first,
                )
                .decoration
            as BoxDecoration;
    final border = decoration.border! as Border;
    expect(border.top.width, 1);
    expect(border.top.style, BorderStyle.solid);
    expect(border.bottom, BorderSide.none);
    expect(
      decoration.borderRadius,
      const BorderRadius.vertical(top: Radius.circular(28)),
    );

    await tester.drag(divider, const Offset(0, -50));
    await tester.pumpAndSettle();
    final expandedHeight = tester.getSize(picker).height;
    expect(expandedHeight, greaterThan(initialHeight));
    expect(tester.state(picker), same(pickerState));
    expect(tester.getBottomLeft(divider).dy, tester.getTopLeft(picker).dy);
    expect(tester.widget<EmbeddedPhotoPicker>(picker).expanded, isTrue);

    await tester.drag(divider, const Offset(0, 80));
    await tester.pumpAndSettle();
    final reducedHeight = tester.getSize(picker).height;
    expect(reducedHeight, lessThan(expandedHeight));
    expect(tester.state(picker), same(pickerState));
    await tester.tap(find.byTooltip('Close picker'));
    await tester.pumpAndSettle();
    expect(divider, findsNothing);
    await tester.tap(find.byTooltip('Open picker'));
    await tester.pumpAndSettle();
    expect(tester.getSize(picker).height, reducedHeight);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'divider stays bounded above and drags closed on a small screen',
    (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(const MaterialApp(home: PickerExample()));
      await tester.tap(find.byTooltip('Open picker'));
      await tester.pumpAndSettle();
      final divider = find.bySemanticsLabel('Resize photo picker');
      final picker = find.byType(EmbeddedPhotoPicker);
      await tester.drag(divider, const Offset(0, -1000));
      await tester.pumpAndSettle();
      expect(
        tester.getTopLeft(divider).dy,
        greaterThanOrEqualTo(
          tester.getBottomLeft(find.widgetWithText(FilledButton, 'Post')).dy,
        ),
      );
      expect(tester.getBottomLeft(picker).dy, closeTo(568, 0.01));
      await tester.drag(divider, const Offset(0, 1000));
      await tester.pumpAndSettle();
      expect(picker, findsNothing);
      expect(divider, findsNothing);
      await tester.tap(find.byTooltip('Open picker'));
      await tester.pumpAndSettle();
      expect(tester.getSize(picker).height, greaterThan(0));
      expect(divider.hitTestable(), findsOneWidget);
      expect(tester.getBottomLeft(picker).dy, closeTo(568, 0.01));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('successive drag updates track movement before dismissing', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: PickerExample()));
    await tester.tap(find.byTooltip('Open picker'));
    await tester.pumpAndSettle();
    final divider = find.bySemanticsLabel('Resize photo picker');
    final picker = find.byType(EmbeddedPhotoPicker);
    final gesture = await tester.startGesture(tester.getCenter(divider));
    await gesture.moveBy(const Offset(0, 25));
    await tester.pump();
    final initialTop = tester.getTopLeft(divider).dy;
    await gesture.moveBy(const Offset(0, 20));
    await gesture.moveBy(const Offset(0, 20));
    await tester.pump();
    expect(tester.getTopLeft(divider).dy, closeTo(initialTop + 40, 0.01));
    await gesture.moveBy(const Offset(0, 1000));
    await gesture.up();
    await tester.pump();
    expect(picker, findsOneWidget);
    await tester.pumpAndSettle();
    expect(picker, findsNothing);
    expect(divider, findsNothing);
    await tester.tap(find.byTooltip('Open picker'));
    await tester.pumpAndSettle();
    expect(tester.getSize(picker).height, greaterThan(0));
    expect(tester.takeException(), isNull);
  });

  testWidgets('maximum picker height leaves selected previews usable', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    const mediaChannel = MethodChannel('embedded_photo_picker/media');
    messenger.setMockMethodCallHandler(mediaChannel, (_) async {
      throw PlatformException(code: 'thumbnail_unavailable');
    });
    addTearDown(() => messenger.setMockMethodCallHandler(mediaChannel, null));
    await tester.pumpWidget(const MaterialApp(home: PickerExample()));
    await tester.tap(find.byTooltip('Open picker'));
    await tester.pumpAndSettle();
    final divider = find.bySemanticsLabel('Resize photo picker');
    await tester.drag(divider, const Offset(0, -1000));
    await tester.pumpAndSettle();
    tester
        .widget<EmbeddedPhotoPicker>(find.byType(EmbeddedPhotoPicker))
        .onUrisGranted([Uri.parse('content://media/picker/1')]);
    await tester.pumpAndSettle();
    await tester.drag(divider, const Offset(0, -1000));
    await tester.pumpAndSettle();
    final preview = find.byType(SelectedMediaPreview);
    expect(tester.getSize(preview).height, greaterThanOrEqualTo(64));
    expect(
      tester.getBottomLeft(preview).dy,
      lessThanOrEqualTo(tester.getTopLeft(divider).dy),
    );
    await tester.drag(divider, const Offset(0, 1000));
    await tester.pumpAndSettle();
    expect(find.byType(EmbeddedPhotoPicker), findsNothing);
    expect(preview, findsOneWidget);
    await tester.tap(find.byTooltip('Open picker'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<EmbeddedPhotoPicker>(find.byType(EmbeddedPhotoPicker))
          .options
          .preselectedUris,
      [Uri.parse('content://media/picker/1')],
    );
    await tester.tap(find.byTooltip('Remove attachment'));
    await tester.pumpAndSettle();
    expect(preview, findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('picker can close while availability is pending', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: PickerExample()));
    await tester.pumpAndSettle();

    final availability = Completer<bool>();
    messenger.setMockMethodCallHandler(channel, (_) => availability.future);
    await tester.tap(find.byTooltip('Open picker'));
    await tester.pump();
    expect(find.byType(EmbeddedPhotoPicker), findsOneWidget);
    await tester.tap(find.byTooltip('Close picker'));
    await tester.pump();
    expect(find.byType(EmbeddedPhotoPicker), findsNothing);
    availability.complete(false);
    await tester.pumpAndSettle();
    expect(find.byType(EmbeddedPhotoPicker), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('picker skips slides when animations are disabled', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(disableAnimations: true),
          child: PickerExample(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Open picker'));
    await tester.pumpAndSettle();
    await tester.drag(
      find.bySemanticsLabel('Resize photo picker'),
      const Offset(0, 1000),
    );
    await tester.pump();
    expect(find.byType(EmbeddedPhotoPicker), findsNothing);
    await tester.tap(find.byTooltip('Open picker'));
    await tester.pumpAndSettle();
    expect(find.text('Picker unavailable'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
