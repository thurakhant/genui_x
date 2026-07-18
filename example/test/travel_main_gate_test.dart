import 'package:flutter_test/flutter_test.dart';
import 'package:genui_x_example/travel_main.dart';

void main() {
  testWidgets('BYOK gate shows all provider choices when no key is compiled in',
      (tester) async {
    await tester.pumpWidget(const GenUiXTravelApp());

    expect(find.byType(ApiKeyGate), findsOneWidget);
    expect(find.text('Claude'), findsOneWidget);
    expect(find.text('OpenAI'), findsOneWidget);
    expect(find.text('Gemini'), findsOneWidget);
  });

  testWidgets('selecting a provider updates the key field label',
      (tester) async {
    await tester.pumpWidget(const GenUiXTravelApp());

    expect(find.text('Claude API key'), findsOneWidget);

    await tester.tap(find.text('OpenAI'));
    await tester.pump();

    expect(find.text('OpenAI API key'), findsOneWidget);
    expect(find.text('Claude API key'), findsNothing);
  });
}
