import 'package:embedded_photo_picker_example/chat_message_bubble.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('labels incoming and outgoing messages', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              ChatMessageBubble(text: 'Hello', outgoing: false),
              ChatMessageBubble(text: 'Hi', outgoing: true),
            ],
          ),
        ),
      ),
    );
    expect(find.text('Ahmed'), findsOneWidget);
    expect(find.text('Me'), findsOneWidget);
    expect(find.text('Hello'), findsOneWidget);
    expect(find.text('Hi'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
