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
    expect(find.text('Settings'), findsOneWidget);
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

    await tester.tap(find.text('Calendar'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Progress'));
    await tester.pump();

    expect(find.text('0.0%'), findsOneWidget);

    final restartedBar = tester.widget<LinearProgressIndicator>(
      find.byKey(const Key('year-progress-bar')),
    );
    expect(restartedBar.value, 0);
  });

  testWidgets('switches to a scrollable year calendar page', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(home: AppShell(today: DateTime(2026, 10, 2, 12))),
    );

    await tester.tap(find.text('Calendar'));
    await tester.pumpAndSettle();

    expect(find.text('Year Calendar'), findsOneWidget);
    expect(find.byKey(const Key('year-calendar-list')), findsOneWidget);
    expect(find.text('October 2026'), findsOneWidget);
    expect(
      tester.widget<SingleChildScrollView>(
        find.byKey(const Key('year-calendar-list')),
      ),
      isNotNull,
    );
  });

  testWidgets('shows settings page and applies a custom year cycle', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: AppShell(
          today: DateTime(2026, 12, 30, 12),
          initialSettings: YearCycleSettings.custom(
            customStart: DateTime(2026, 7, 1),
          ),
        ),
      ),
    );

    await tester.pump(const Duration(milliseconds: 180));
    await tester.pump(const Duration(milliseconds: 2400));

    expect(find.text('50.0%'), findsOneWidget);
    expect(find.text('Cycle: July 1, 2026 to July 1, 2027'), findsNothing);

    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();

    expect(find.text('Year Start'), findsOneWidget);
    expect(find.byKey(const Key('custom-year-start-option')), findsOneWidget);
    expect(find.text('Select date'), findsOneWidget);
    expect(find.text('Goal'), findsOneWidget);
    expect(find.byKey(const Key('goal-name-field')), findsOneWidget);
    expect(find.text('Select goal date'), findsOneWidget);
  });

  testWidgets('shows goal progress and highlights the goal date in calendar', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: AppShell(
          today: DateTime(2026, 7, 2, 12),
          initialGoal: GoalEntry(
            name: 'Launch MVP',
            date: DateTime(2026, 8, 15),
          ),
        ),
      ),
    );

    expect(find.byKey(const Key('goal-progress-card')), findsOneWidget);
    expect(find.text('Launch MVP'), findsOneWidget);
    expect(find.text('Goal date: August 15, 2026'), findsOneWidget);
    expect(find.text('44 days until this goal.'), findsOneWidget);

    await tester.tap(find.text('Calendar'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('goal-calendar-date')), findsOneWidget);

    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('current-goal-summary')), findsOneWidget);
    expect(
      find.text('Current goal: Launch MVP on August 15, 2026'),
      findsOneWidget,
    );
  });
}
