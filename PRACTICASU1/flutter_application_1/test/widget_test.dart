import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:namer_app/main.dart';

void main() {
  testWidgets('Next button shows a new word pair', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());

    expect(find.text('A random idea:'), findsOneWidget);
    expect(find.widgetWithText(ElevatedButton, 'Next'), findsOneWidget);

    await tester.tap(find.text('Next'));
    await tester.pump();

    expect(find.text('A random idea:'), findsOneWidget);
  });
}
