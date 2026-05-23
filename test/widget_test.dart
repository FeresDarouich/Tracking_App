import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:trackingapp/main.dart';

void main() {
  testWidgets('shows year completion bar and label', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(home: YearProgressPage(today: DateTime(2026, 7, 2, 12))),
    );

    expect(find.text('Year Completion'), findsOneWidget);
    expect(find.byKey(const Key('year-progress-bar')), findsOneWidget);
    expect(find.byKey(const Key('year-progress-label')), findsOneWidget);
    expect(find.text('50.0%'), findsOneWidget);
  });
}
