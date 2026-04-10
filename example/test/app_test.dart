import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genui_x_example/main.dart';

void main() {
  testWidgets('renders basic chat UI', (tester) async {
    await tester.pumpWidget(
      const GenUiXExampleApp(apiKey: 'test-key'),
    );

    expect(find.text('GenUI + X'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
    expect(find.text('Ask about the weather...'), findsOneWidget);
    expect(find.byIcon(Icons.send), findsOneWidget);
  });
}
