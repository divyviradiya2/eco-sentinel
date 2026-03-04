import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Smoke test — app widget renders', (WidgetTester tester) async {
    // Minimal smoke test; full widget tests are deferred until Firebase
    // mock infrastructure is set up in a later story.
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: Text('Swachh Campus 360'))),
    );

    expect(find.text('Swachh Campus 360'), findsOneWidget);
  });
}
