import 'package:embedded_photo_picker/embedded_photo_picker.dart';
import 'package:embedded_photo_picker_example/chat_example.dart';
import 'package:embedded_photo_picker_example/example_home.dart';
import 'package:embedded_photo_picker_example/picker_example.dart';
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

  testWidgets('chooser opens compose and chat and returns home', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const MaterialApp(home: ExampleHome()));
    expect(find.byType(EmbeddedPhotoPicker), findsNothing);
    final composeButton = find.widgetWithText(FilledButton, 'Compose');
    final chatButton = find.widgetWithText(FilledButton, 'Chat');
    final composeCaption = find.text('Expanded photo picker');
    final chatCaption = find.text('Collapsed photo picker');
    expect(composeCaption, findsOneWidget);
    expect(chatCaption, findsOneWidget);
    expect(
      tester.getTopLeft(composeCaption).dy,
      greaterThan(tester.getBottomLeft(composeButton).dy),
    );
    expect(
      tester.getBottomLeft(composeCaption).dy,
      lessThan(tester.getTopLeft(chatButton).dy),
    );
    expect(
      tester.getTopLeft(chatCaption).dy,
      greaterThan(tester.getBottomLeft(chatButton).dy),
    );
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Compose'));
    await tester.pumpAndSettle();
    expect(find.byType(PickerExample), findsOneWidget);
    expect(find.byType(EmbeddedPhotoPicker), findsNothing);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Compose'), findsOneWidget);
    await tester.tap(find.text('Chat'));
    await tester.pumpAndSettle();
    expect(find.byType(ChatExample), findsOneWidget);
    expect(find.byType(EmbeddedPhotoPicker), findsNothing);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Chat'), findsOneWidget);
    expect(find.byType(EmbeddedPhotoPicker), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
