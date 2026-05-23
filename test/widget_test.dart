import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:trackingapp/main.dart';

void main() {
  testWidgets('shows progress tab by default and animates year completion', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(home: AppShell(today: DateTime(2026, 7, 2, 12))),
    );

    expect(find.text('Year Completion'), findsOneWidget);
    expect(find.text('Progress'), findsOneWidget);
    expect(find.text('Calendar'), findsOneWidget);
    expect(find.byKey(const Key('year-progress-bar')), findsOneWidget);
    expect(find.byKey(const Key('year-progress-label')), findsOneWidget);
    expect(find.text('0.0%'), findsOneWidget);
    expect(find.text('50.0%'), findsNothing);

    final initialBar = tester.widget<LinearProgressIndicator>(
      find.byKey(const Key('year-progress-bar')),
    );
    expect(initialBar.value, 0);

    await tester.pump();

    final delayedStartBar = tester.widget<LinearProgressIndicator>(
      find.byKey(const Key('year-progress-bar')),
    );
    expect(delayedStartBar.value, 0);

    await tester.pump(const Duration(milliseconds: 180));
    await tester.pump(const Duration(milliseconds: 1200));

    final midAnimationBar = tester.widget<LinearProgressIndicator>(
      find.byKey(const Key('year-progress-bar')),
    );
    expect(midAnimationBar.value, greaterThan(0));
    expect(midAnimationBar.value, lessThan(0.5));

    final midAnimationLabel = tester.widget<Text>(
      find.byKey(const Key('year-progress-label')),
    );
    expect(midAnimationLabel.data, isNot('0.0%'));
    expect(midAnimationLabel.data, isNot('50.0%'));

    await tester.pump(const Duration(milliseconds: 1200));

    final animatedBar = tester.widget<LinearProgressIndicator>(
      find.byKey(const Key('year-progress-bar')),
    );
    expect(animatedBar.value, 0.5);
    expect(find.text('50.0%'), findsOneWidget);
  });

  testWidgets('switches to a scrollable year calendar page', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(home: AppShell(today: DateTime(2026, 7, 2, 12))),
    );

    await tester.tap(find.text('Calendar'));
    await tester.pumpAndSettle();

    expect(find.text('Year Calendar'), findsOneWidget);
    expect(find.byKey(const Key('year-calendar-list')), findsOneWidget);
    expect(
      tester.widget<ListView>(find.byKey(const Key('year-calendar-list'))),
      isNotNull,
    );
  });
}
