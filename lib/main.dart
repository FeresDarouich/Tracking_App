import 'dart:async';

import 'package:flutter/material.dart';

void main() {
  runApp(const MyApp());
}

const _monthNames = <String>[
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];

const _weekdayLabels = <String>['Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa', 'Su'];

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF00FF38),
        brightness: Brightness.dark,
      ),
      scaffoldBackgroundColor: const Color(0xFF000000),
      cardColor: const Color(0xFF050505),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF000000),
        foregroundColor: Colors.white,
      ),
      useMaterial3: true,
    );

    return MaterialApp(
      title: 'Year Progress',
      theme: theme,
      home: const AppShell(),
    );
  }
}

class AppShell extends StatefulWidget {
  const AppShell({super.key, DateTime? today}) : _today = today;

  final DateTime? _today;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final today = widget._today ?? DateTime.now();
    final pages = [
      YearProgressPage(today: today),
      YearCalendarPage(year: today.year, today: today),
    ];
    final titles = ['Year Completion', 'Year Calendar'];

    return Scaffold(
      appBar: AppBar(title: Text(titles[_selectedIndex])),
      body: IndexedStack(index: _selectedIndex, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.insights_outlined),
            selectedIcon: Icon(Icons.insights),
            label: 'Progress',
          ),
          NavigationDestination(
            icon: Icon(Icons.calendar_month_outlined),
            selectedIcon: Icon(Icons.calendar_month),
            label: 'Calendar',
          ),
        ],
      ),
    );
  }
}

class YearProgressPage extends StatefulWidget {
  const YearProgressPage({super.key, DateTime? today}) : _today = today;

  final DateTime? _today;

  @override
  State<YearProgressPage> createState() => _YearProgressPageState();
}

class _YearProgressPageState extends State<YearProgressPage>
    with SingleTickerProviderStateMixin {
  static const _animationDuration = Duration(milliseconds: 2400);

  late final AnimationController _controller;
  Timer? _startTimer;
  bool _hasAnimationStarted = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: _animationDuration,
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _startTimer = Timer(const Duration(milliseconds: 180), () {
          if (mounted) {
            setState(() {
              _hasAnimationStarted = true;
            });
            _controller.forward(from: 0);
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _startTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final now = widget._today ?? DateTime.now();
    final progress = _yearCompletionRate(now);
    final dayOfYear = _dayOfYear(now);
    final totalDays = _totalDaysInYear(now.year);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(28),
            ),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'How far through ${now.year}?',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Today is day $dayOfYear of $totalDays.',
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 24),
                  AnimatedBuilder(
                    animation: _controller,
                    builder: (context, child) {
                      final animatedProgress = _hasAnimationStarted
                          ? progress *
                                Curves.easeOutCubic.transform(_controller.value)
                          : 0.0;
                      final animatedPercentageLabel =
                          '${(animatedProgress * 100).toStringAsFixed(1)}%';

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          LinearProgressIndicator(
                            key: const Key('year-progress-bar'),
                            value: animatedProgress,
                            minHeight: 24,
                            color: const Color(0xFF00FF38),
                            backgroundColor: const Color(0xFF4A4A4A),
                            borderRadius: BorderRadius.zero,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            animatedPercentageLabel,
                            key: const Key('year-progress-label'),
                            style: Theme.of(context).textTheme.displaySmall
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${totalDays - dayOfYear} days remaining in the year.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class YearCalendarPage extends StatelessWidget {
  const YearCalendarPage({super.key, required this.year, required this.today});

  final int year;
  final DateTime today;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      key: const Key('year-calendar-list'),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
      itemCount: 12,
      itemBuilder: (context, index) {
        return _MonthCard(month: index + 1, year: year, today: today);
      },
    );
  }
}

class _MonthCard extends StatelessWidget {
  const _MonthCard({
    required this.month,
    required this.year,
    required this.today,
  });

  final int month;
  final int year;
  final DateTime today;

  @override
  Widget build(BuildContext context) {
    final daysInMonth = DateTime(year, month + 1, 0).day;
    final firstDay = DateTime(year, month, 1);
    final leadingEmptySlots = (firstDay.weekday + 6) % 7;
    final totalCells = leadingEmptySlots + daysInMonth;
    final trailingEmptySlots = (7 - (totalCells % 7)) % 7;
    final cells = List<int?>.filled(leadingEmptySlots, null, growable: true)
      ..addAll(List<int?>.generate(daysInMonth, (index) => index + 1))
      ..addAll(List<int?>.filled(trailingEmptySlots, null));

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      color: Colors.transparent,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${_monthNames[month - 1]} $year',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 16),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _weekdayLabels.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              childAspectRatio: 1.5,
            ),
            itemBuilder: (context, index) {
              return Center(
                child: Text(
                  _weekdayLabels[index],
                  style: Theme.of(
                    context,
                  ).textTheme.labelMedium?.copyWith(color: Colors.white70),
                ),
              );
            },
          ),
          const SizedBox(height: 8),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: cells.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              childAspectRatio: 1.05,
            ),
            itemBuilder: (context, index) {
              final day = cells[index];
              final cellDate = day == null ? null : DateTime(year, month, day);
              final todayDate = DateTime(today.year, today.month, today.day);
              final isToday =
                  day != null &&
                  today.year == year &&
                  today.month == month &&
                  today.day == day;
              final isPastDay =
                  cellDate != null && cellDate.isBefore(todayDate) && !isToday;

              return Center(
                child: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: day == null
                        ? Colors.transparent
                        : isToday
                        ? const Color(0xFF00FF38).withValues(alpha: 0.2)
                        : isPastDay
                        ? const Color(0xFFFF3B30).withValues(alpha: 0.2)
                        : const Color(0xFF111111).withValues(alpha: 0.45),
                    border: Border.all(
                      color: day == null
                          ? Colors.transparent
                          : isToday
                          ? const Color(0xFF00FF38)
                          : isPastDay
                          ? const Color(0xFFFF3B30)
                          : const Color(0xFF2E2E2E),
                    ),
                  ),
                  child: Center(
                    child: Text(
                      day?.toString() ?? '',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: day == null ? Colors.transparent : Colors.white,
                        fontWeight: isToday ? FontWeight.w700 : FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

double _yearCompletionRate(DateTime date) {
  final startOfYear = DateTime(date.year);
  final startOfNextYear = DateTime(date.year + 1);
  final elapsed = date.difference(startOfYear).inSeconds;
  final total = startOfNextYear.difference(startOfYear).inSeconds;

  return (elapsed / total).clamp(0.0, 1.0);
}

int _dayOfYear(DateTime date) {
  return date.difference(DateTime(date.year)).inDays + 1;
}

int _totalDaysInYear(int year) {
  return DateTime(year + 1).difference(DateTime(year)).inDays;
}
