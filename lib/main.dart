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

enum YearStartMode { normal, custom }

class YearCycleSettings {
  const YearCycleSettings._({required this.mode, this.customStart});

  const YearCycleSettings.normal() : this._(mode: YearStartMode.normal);

  const YearCycleSettings.custom({required DateTime customStart})
    : this._(mode: YearStartMode.custom, customStart: customStart);

  final YearStartMode mode;
  final DateTime? customStart;

  YearCycleSettings copyWith({YearStartMode? mode, DateTime? customStart}) {
    return YearCycleSettings._(
      mode: mode ?? this.mode,
      customStart: customStart ?? this.customStart,
    );
  }
}

class YearCycleRange {
  const YearCycleRange({
    required this.start,
    required this.endExclusive,
    required this.displayEnd,
  });

  final DateTime start;
  final DateTime endExclusive;
  final DateTime displayEnd;
}

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
      debugShowCheckedModeBanner: false,
      theme: theme,
      home: const AppShell(),
    );
  }
}

class AppShell extends StatefulWidget {
  const AppShell({
    super.key,
    DateTime? today,
    YearCycleSettings? initialSettings,
  }) : _today = today,
       _initialSettings = initialSettings;

  final DateTime? _today;
  final YearCycleSettings? _initialSettings;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _selectedIndex = 0;
  int _progressPageVersion = 0;
  int _calendarPageVersion = 0;
  late YearCycleSettings _settings;

  @override
  void initState() {
    super.initState();
    _settings = widget._initialSettings ?? const YearCycleSettings.normal();
  }

  void _updateYearStartMode(YearStartMode mode) {
    final today = _dateOnly(widget._today ?? DateTime.now());

    setState(() {
      _settings = _settings.copyWith(
        mode: mode,
        customStart: mode == YearStartMode.custom
            ? _dateOnly(_settings.customStart ?? today)
            : _settings.customStart,
      );
      _progressPageVersion++;
    });
  }

  void _updateCustomStart(DateTime customStart) {
    setState(() {
      _settings = _settings.copyWith(
        mode: YearStartMode.custom,
        customStart: _dateOnly(customStart),
      );
      _progressPageVersion++;
    });
  }

  @override
  Widget build(BuildContext context) {
    final today = widget._today ?? DateTime.now();
    final cycle = _resolveYearCycle(today, _settings);
    final pages = [
      YearProgressPage(
        key: ValueKey(_progressPageVersion),
        today: today,
        settings: _settings,
        cycle: cycle,
      ),
      YearCalendarPage(
        key: ValueKey(_calendarPageVersion),
        today: today,
        cycle: cycle,
      ),
      SettingsPage(
        today: today,
        settings: _settings,
        onModeChanged: _updateYearStartMode,
        onCustomStartChanged: _updateCustomStart,
      ),
    ];
    final titles = ['Year Completion', 'Year Calendar', 'Settings'];

    return Scaffold(
      appBar: AppBar(title: Text(titles[_selectedIndex])),
      body: IndexedStack(index: _selectedIndex, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) {
          setState(() {
            if (index == 0) {
              _progressPageVersion++;
            }
            if (index == 1) {
              _calendarPageVersion++;
            }
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
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}

class YearProgressPage extends StatefulWidget {
  const YearProgressPage({
    super.key,
    DateTime? today,
    required this.settings,
    required this.cycle,
  }) : _today = today;

  final DateTime? _today;
  final YearCycleSettings settings;
  final YearCycleRange cycle;

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
    final progress = _cycleCompletionRate(now, widget.cycle);
    final elapsedDays = _elapsedCycleDays(now, widget.cycle);
    final totalDays = widget.cycle.endExclusive
        .difference(widget.cycle.start)
        .inDays;
    final remainingDays = _remainingCycleDays(now, widget.cycle);
    final title = widget.settings.mode == YearStartMode.normal
        ? 'How far through ${widget.cycle.start.year}?'
        : 'How far through your custom year?';
    final statusLabel = now.isBefore(widget.cycle.start)
        ? 'This cycle has not started yet.'
        : now.isBefore(widget.cycle.endExclusive)
        ? 'Today is day $elapsedDays of $totalDays in this cycle.'
        : 'This cycle is complete.';
    final footerLabel = now.isBefore(widget.cycle.start)
        ? '${widget.cycle.start.difference(_dateOnly(now)).inDays} days until this cycle starts.'
        : now.isBefore(widget.cycle.endExclusive)
        ? '$remainingDays days remaining in this cycle.'
        : 'Cycle completed on ${_formatDate(widget.cycle.displayEnd)}.';

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
                  Text(title, style: Theme.of(context).textTheme.headlineSmall),
                  const SizedBox(height: 12),
                  Text(
                    statusLabel,
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
                            minHeight: 30,
                            color: const Color(0xFFFF3B30),
                            backgroundColor: const Color(0xFF4A4A4A),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            animatedPercentageLabel,
                            key: const Key('year-progress-label'),
                            style: Theme.of(context).textTheme.displaySmall
                                ?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFFFF3B30),
                                ),
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 8),
                  Text(
                    footerLabel,
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

class YearCalendarPage extends StatefulWidget {
  const YearCalendarPage({super.key, required this.today, required this.cycle});

  final DateTime today;
  final YearCycleRange cycle;

  @override
  State<YearCalendarPage> createState() => _YearCalendarPageState();
}

class _YearCalendarPageState extends State<YearCalendarPage> {
  late final ScrollController _scrollController;
  late final List<DateTime> _months;
  late final List<GlobalKey> _monthKeys;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _months = _monthsInRange(widget.cycle);
    _monthKeys = List<GlobalKey>.generate(_months.length, (_) => GlobalKey());

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _months.isEmpty) {
        return;
      }

      final targetIndex = _targetMonthIndex(
        _months,
        widget.today,
        widget.cycle,
      );
      final targetContext = _monthKeys[targetIndex].currentContext;

      if (targetContext != null) {
        Scrollable.ensureVisible(
          targetContext,
          alignment: 0.5,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOutCubic,
        );
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      controller: _scrollController,
      key: const Key('year-calendar-list'),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
      child: Column(
        children: List<Widget>.generate(_months.length, (index) {
          final monthDate = _months[index];

          return KeyedSubtree(
            key: _monthKeys[index],
            child: _MonthCard(
              month: monthDate.month,
              year: monthDate.year,
              today: widget.today,
              cycle: widget.cycle,
            ),
          );
        }),
      ),
    );
  }
}

class SettingsPage extends StatelessWidget {
  const SettingsPage({
    super.key,
    required this.today,
    required this.settings,
    required this.onModeChanged,
    required this.onCustomStartChanged,
  });

  final DateTime today;
  final YearCycleSettings settings;
  final ValueChanged<YearStartMode> onModeChanged;
  final ValueChanged<DateTime> onCustomStartChanged;

  @override
  Widget build(BuildContext context) {
    final effectiveCustomStart = _dateOnly(settings.customStart ?? today);

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Year Start',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                Text(
                  'Choose whether the app uses the normal calendar year or a custom one-year cycle.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 16),
                RadioListTile<YearStartMode>(
                  key: const Key('normal-year-start-option'),
                  value: YearStartMode.normal,
                  groupValue: settings.mode,
                  title: const Text('Normal'),
                  subtitle: const Text('January 1 to December 31'),
                  onChanged: (value) {
                    if (value != null) {
                      onModeChanged(value);
                    }
                  },
                ),
                RadioListTile<YearStartMode>(
                  key: const Key('custom-year-start-option'),
                  value: YearStartMode.custom,
                  groupValue: settings.mode,
                  title: const Text('Custom'),
                  subtitle: const Text(
                    'Start from a date and end on the same date next year',
                  ),
                  onChanged: (value) {
                    if (value != null) {
                      onModeChanged(value);
                    }
                  },
                ),
                if (settings.mode == YearStartMode.custom) ...[
                  const SizedBox(height: 12),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Custom start date'),
                    subtitle: Text(_formatDate(effectiveCustomStart)),
                    trailing: FilledButton.tonal(
                      onPressed: () async {
                        final pickedDate = await showDatePicker(
                          context: context,
                          initialDate: effectiveCustomStart,
                          firstDate: DateTime(2000),
                          lastDate: DateTime(2100),
                        );

                        if (pickedDate != null) {
                          onCustomStartChanged(pickedDate);
                        }
                      },
                      child: const Text('Select date'),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _MonthCard extends StatelessWidget {
  const _MonthCard({
    required this.month,
    required this.year,
    required this.today,
    required this.cycle,
  });

  final int month;
  final int year;
  final DateTime today;
  final YearCycleRange cycle;

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
              final isInCycle =
                  cellDate != null &&
                  !_dateOnly(cellDate).isBefore(_dateOnly(cycle.start)) &&
                  !_dateOnly(cellDate).isAfter(_dateOnly(cycle.displayEnd));
              final isToday =
                  isInCycle &&
                  today.year == year &&
                  today.month == month &&
                  today.day == day;
              final isPastDay =
                  isInCycle &&
                  cellDate != null &&
                  cellDate.isBefore(todayDate) &&
                  !isToday;

              return Center(
                child: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: day == null
                        ? Colors.transparent
                        : !isInCycle
                        ? Colors.transparent
                        : isToday
                        ? const Color(0xFF00FF38).withValues(alpha: 0.2)
                        : isPastDay
                        ? const Color(0xFFFF3B30).withValues(alpha: 0.2)
                        : const Color(0xFF111111).withValues(alpha: 0.45),
                    border: Border.all(
                      color: day == null
                          ? Colors.transparent
                          : !isInCycle
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
                        color: day == null || !isInCycle
                            ? Colors.transparent
                            : Colors.white,
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

YearCycleRange _resolveYearCycle(DateTime today, YearCycleSettings settings) {
  if (settings.mode == YearStartMode.custom && settings.customStart != null) {
    final start = _dateOnly(settings.customStart!);
    final endExclusive = DateTime(start.year + 1, start.month, start.day);

    return YearCycleRange(
      start: start,
      endExclusive: endExclusive,
      displayEnd: endExclusive,
    );
  }

  final start = DateTime(today.year);
  final endExclusive = DateTime(today.year + 1);

  return YearCycleRange(
    start: start,
    endExclusive: endExclusive,
    displayEnd: DateTime(today.year, 12, 31),
  );
}

double _cycleCompletionRate(DateTime date, YearCycleRange cycle) {
  final elapsed = date.difference(cycle.start).inSeconds;
  final total = cycle.endExclusive.difference(cycle.start).inSeconds;

  return (elapsed / total).clamp(0.0, 1.0);
}

int _elapsedCycleDays(DateTime date, YearCycleRange cycle) {
  if (date.isBefore(cycle.start)) {
    return 0;
  }

  if (!date.isBefore(cycle.endExclusive)) {
    return cycle.endExclusive.difference(cycle.start).inDays;
  }

  return date.difference(cycle.start).inDays + 1;
}

int _remainingCycleDays(DateTime date, YearCycleRange cycle) {
  if (date.isBefore(cycle.start)) {
    return cycle.endExclusive.difference(cycle.start).inDays;
  }

  if (!date.isBefore(cycle.endExclusive)) {
    return 0;
  }

  return cycle.endExclusive.difference(date).inDays;
}

List<DateTime> _monthsInRange(YearCycleRange cycle) {
  final months = <DateTime>[];
  var cursor = DateTime(cycle.start.year, cycle.start.month);
  final endMonth = DateTime(cycle.displayEnd.year, cycle.displayEnd.month);

  while (!cursor.isAfter(endMonth)) {
    months.add(cursor);
    cursor = DateTime(cursor.year, cursor.month + 1);
  }

  return months;
}

int _targetMonthIndex(
  List<DateTime> months,
  DateTime today,
  YearCycleRange cycle,
) {
  final targetMonth = DateTime(today.year, today.month);
  final exactIndex = months.indexWhere(
    (month) =>
        month.year == targetMonth.year && month.month == targetMonth.month,
  );

  if (exactIndex != -1) {
    return exactIndex;
  }

  if (_dateOnly(today).isBefore(cycle.start)) {
    return 0;
  }

  return months.length - 1;
}

DateTime _dateOnly(DateTime date) {
  return DateTime(date.year, date.month, date.day);
}

String _formatDate(DateTime date) {
  return '${_monthNames[date.month - 1]} ${date.day}, ${date.year}';
}
