import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genui_x_example/main.dart';
import 'package:genui_x_example/src/chat_page.dart';

void main() {
  testWidgets('renders basic chat UI', (tester) async {
    await tester.pumpWidget(
      const TravelDemoApp(apiKey: 'test-key'),
    );

    expect(find.byType(TravelChatPage), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
  });
}
