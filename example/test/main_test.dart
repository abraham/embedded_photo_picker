import 'package:embedded_photo_picker_example/main.dart' as example;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('embedded_photo_picker');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  setUp(
    () => messenger.setMockMethodCallHandler(
      channel,
      (_) async => {
        'available': false,
        'androidApiLevel': 0,
        'uExtensionVersion': 0,
      },
    ),
  );
  tearDown(() => messenger.setMockMethodCallHandler(channel, null));
  testWidgets('example launches and toggles picker', (tester) async {
    example.main();
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<MaterialApp>(find.byType(MaterialApp))
          .debugShowCheckedModeBanner,
      isFalse,
    );
    expect(find.text('Compose'), findsOneWidget);
    expect(find.text('Chat'), findsOneWidget);
    expect(find.text('Picker unavailable'), findsNothing);
    await tester.tap(find.text('Compose'));
    await tester.pumpAndSettle();
    expect(find.text('Photo picker'), findsOneWidget);
    expect(find.text('Picker unavailable'), findsNothing);
    await tester.tap(find.byTooltip('Open picker'));
    await tester.pumpAndSettle();
    expect(find.text('Picker unavailable'), findsOneWidget);
    await tester.tap(find.byTooltip('Close picker'));
    await tester.pumpAndSettle();
    expect(find.text('Picker unavailable'), findsNothing);
    await tester.tap(find.byTooltip('Open picker'));
    await tester.pumpAndSettle();
    expect(find.text('Picker unavailable'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'A message');
    expect(find.text('A message'), findsOneWidget);
  });
}
