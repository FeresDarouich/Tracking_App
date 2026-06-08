import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

const _goalAccentPalette = <Color>[
  Color(0xFFFFD60A),
  Color(0xFF5AC8FA),
  Color(0xFFFF9F0A),
  Color(0xFFBF5AF2),
  Color(0xFF64D2FF),
  Color(0xFF30D158),
  Color(0xFFFF375F),
  Color(0xFF00C7BE),
];

enum YearStartMode { normal, custom }

class GoalEntry {
  const GoalEntry({required this.name, required this.date});

  final String name;
  final DateTime date;

  GoalEntry copyWith({String? name, DateTime? date}) {
    return GoalEntry(name: name ?? this.name, date: date ?? this.date);
  }
}

class TodoNoteEntry {
  const TodoNoteEntry({
    required this.id,
    required this.title,
    required this.completed,
    required this.createdAt,
  });

  final String id;
  final String title;
  final bool completed;
  final DateTime createdAt;

  TodoNoteEntry copyWith({
    String? title,
    bool? completed,
    DateTime? createdAt,
  }) {
    return TodoNoteEntry(
      id: id,
      title: title ?? this.title,
      completed: completed ?? this.completed,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

class ExpenseEntry {
  const ExpenseEntry({
    required this.id,
    required this.title,
    required this.amount,
    required this.date,
  });

  final String id;
  final String title;
  final double amount;
  final DateTime date;

  ExpenseEntry copyWith({String? title, double? amount, DateTime? date}) {
    return ExpenseEntry(
      id: id,
      title: title ?? this.title,
      amount: amount ?? this.amount,
      date: date ?? this.date,
    );
  }
}

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

class PersistedAppState {
  const PersistedAppState({
    required this.settings,
    required this.goals,
    required this.todoNotes,
    required this.expenses,
  });

  final YearCycleSettings settings;
  final List<GoalEntry> goals;
  final List<TodoNoteEntry> todoNotes;
  final List<ExpenseEntry> expenses;
}

class AppStorage {
  static const _yearStartModeKey = 'year_start_mode';
  static const _customStartKey = 'custom_start_date';
  static const _goalsKey = 'goals_v2';
  static const _todoNotesKey = 'todo_notes_v1';
  static const _expenseEntriesKey = 'expense_entries_v1';
  static const _goalNameKey = 'goal_name';
  static const _goalDateKey = 'goal_date';

  static Future<PersistedAppState> load() async {
    final preferences = await SharedPreferences.getInstance();
    final modeName = preferences.getString(_yearStartModeKey);
    final customStartValue = preferences.getString(_customStartKey);
    final goalsPayload = preferences.getString(_goalsKey);
    final todoNotesPayload = preferences.getString(_todoNotesKey);
    final expensesPayload = preferences.getString(_expenseEntriesKey);
    final goalName = preferences.getString(_goalNameKey);
    final goalDateValue = preferences.getString(_goalDateKey);

    final mode =
        YearStartMode.values.cast<YearStartMode?>().firstWhere(
          (value) => value?.name == modeName,
          orElse: () => YearStartMode.normal,
        ) ??
        YearStartMode.normal;

    final customStart = customStartValue == null
        ? null
        : DateTime.tryParse(customStartValue);
    final goals = <GoalEntry>[];
    if (goalsPayload != null) {
      try {
        final decoded = jsonDecode(goalsPayload);
        if (decoded is List) {
          for (final item in decoded) {
            if (item is Map<String, dynamic>) {
              final name = item['name'];
              final dateValue = item['date'];
              if (name is String && dateValue is String) {
                final parsedDate = DateTime.tryParse(dateValue);
                final trimmedName = name.trim();
                if (parsedDate != null && trimmedName.isNotEmpty) {
                  goals.add(
                    GoalEntry(name: trimmedName, date: _dateOnly(parsedDate)),
                  );
                }
              }
            }
          }
        }
      } catch (_) {
        // Fall back to legacy keys when v2 payload is malformed.
      }
    }

    if (goals.isEmpty) {
      final goalDate = goalDateValue == null
          ? null
          : DateTime.tryParse(goalDateValue);
      if (goalName != null && goalName.trim().isNotEmpty && goalDate != null) {
        goals.add(GoalEntry(name: goalName.trim(), date: _dateOnly(goalDate)));
      }
    }

    final todoNotes = _decodeTodoNotes(todoNotesPayload);
    final expenses = _decodeExpenses(expensesPayload);

    return PersistedAppState(
      settings: mode == YearStartMode.custom && customStart != null
          ? YearCycleSettings.custom(customStart: _dateOnly(customStart))
          : const YearCycleSettings.normal(),
      goals: goals,
      todoNotes: todoNotes,
      expenses: expenses,
    );
  }

  static Future<void> save({
    required YearCycleSettings settings,
    required List<GoalEntry> goals,
    required List<TodoNoteEntry> todoNotes,
    required List<ExpenseEntry> expenses,
  }) async {
    final preferences = await SharedPreferences.getInstance();

    await preferences.setString(_yearStartModeKey, settings.mode.name);
    if (settings.customStart == null) {
      await preferences.remove(_customStartKey);
    } else {
      await preferences.setString(
        _customStartKey,
        _dateOnly(settings.customStart!).toIso8601String(),
      );
    }

    if (goals.isEmpty) {
      await preferences.remove(_goalsKey);
      await preferences.remove(_goalNameKey);
      await preferences.remove(_goalDateKey);
    } else {
      final payload = jsonEncode(
        goals
            .map(
              (goal) => <String, String>{
                'name': goal.name.trim(),
                'date': _dateOnly(goal.date).toIso8601String(),
              },
            )
            .toList(),
      );
      await preferences.setString(_goalsKey, payload);

      // Keep legacy single-goal keys in sync with the first goal for compatibility.
      final firstGoal = goals.first;
      await preferences.setString(_goalNameKey, firstGoal.name.trim());
      await preferences.setString(
        _goalDateKey,
        _dateOnly(firstGoal.date).toIso8601String(),
      );
    }

    await preferences.setString(
      _todoNotesKey,
      jsonEncode(
        todoNotes
            .map(
              (note) => <String, Object>{
                'id': note.id,
                'title': note.title.trim(),
                'completed': note.completed,
                'createdAt': note.createdAt.toIso8601String(),
              },
            )
            .toList(),
      ),
    );

    await preferences.setString(
      _expenseEntriesKey,
      jsonEncode(
        expenses
            .map(
              (expense) => <String, Object>{
                'id': expense.id,
                'title': expense.title.trim(),
                'amount': expense.amount,
                'date': _dateOnly(expense.date).toIso8601String(),
              },
            )
            .toList(),
      ),
    );
  }
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
    GoalEntry? initialGoal,
    List<GoalEntry>? initialGoals,
    List<TodoNoteEntry>? initialTodoNotes,
    List<ExpenseEntry>? initialExpenses,
  }) : _today = today,
       _initialSettings = initialSettings,
       _initialGoal = initialGoal,
       _initialGoals = initialGoals,
       _initialTodoNotes = initialTodoNotes,
       _initialExpenses = initialExpenses;

  final DateTime? _today;
  final YearCycleSettings? _initialSettings;
  final GoalEntry? _initialGoal;
  final List<GoalEntry>? _initialGoals;
  final List<TodoNoteEntry>? _initialTodoNotes;
  final List<ExpenseEntry>? _initialExpenses;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _selectedIndex = 0;
  int _progressPageVersion = 0;
  int _calendarPageVersion = 0;
  late YearCycleSettings _settings;
  late List<GoalEntry> _goals;
  late List<TodoNoteEntry> _todoNotes;
  late List<ExpenseEntry> _expenses;

  @override
  void initState() {
    super.initState();
    _settings = widget._initialSettings ?? const YearCycleSettings.normal();
    _goals = List<GoalEntry>.from(
      widget._initialGoals ??
          (widget._initialGoal == null ? const [] : [widget._initialGoal!]),
    );
    _todoNotes = List<TodoNoteEntry>.from(widget._initialTodoNotes ?? const []);
    _expenses = List<ExpenseEntry>.from(widget._initialExpenses ?? const []);

    if (widget._initialSettings == null &&
        widget._initialGoals == null &&
        widget._initialGoal == null &&
        widget._initialTodoNotes == null &&
        widget._initialExpenses == null) {
      unawaited(_loadPersistedState());
    }
  }

  DateTime get _currentToday => widget._today ?? DateTime.now();

  Future<void> _loadPersistedState() async {
    final persistedState = await AppStorage.load();
    final cycle = _resolveYearCycle(_currentToday, persistedState.settings);
    final sanitizedGoals = _sanitizeGoals(persistedState.goals, cycle);
    final sanitizedTodoNotes = _sanitizeTodoNotes(persistedState.todoNotes);
    final sanitizedExpenses = _sanitizeExpenses(persistedState.expenses);

    if (!mounted) {
      return;
    }

    setState(() {
      _settings = persistedState.settings;
      _goals = sanitizedGoals;
      _todoNotes = sanitizedTodoNotes;
      _expenses = sanitizedExpenses;
      _progressPageVersion++;
      _calendarPageVersion++;
    });

    if (!_goalsEqual(sanitizedGoals, persistedState.goals)) {
      unawaited(_persistState());
    }
  }

  Future<void> _persistState() {
    final cycle = _resolveYearCycle(_currentToday, _settings);
    final sanitizedGoals = _sanitizeGoals(_goals, cycle);
    final sanitizedTodoNotes = _sanitizeTodoNotes(_todoNotes);
    final sanitizedExpenses = _sanitizeExpenses(_expenses);

    return AppStorage.save(
      settings: _settings,
      goals: sanitizedGoals,
      todoNotes: sanitizedTodoNotes,
      expenses: sanitizedExpenses,
    );
  }

  void _updateYearStartMode(YearStartMode mode) {
    final today = _dateOnly(_currentToday);

    setState(() {
      _settings = _settings.copyWith(
        mode: mode,
        customStart: mode == YearStartMode.custom
            ? _dateOnly(_settings.customStart ?? today)
            : _settings.customStart,
      );
      _goals = _sanitizeGoals(_goals, _resolveYearCycle(today, _settings));
      _progressPageVersion++;
      _calendarPageVersion++;
    });

    unawaited(_persistState());
  }

  void _updateCustomStart(DateTime customStart) {
    setState(() {
      _settings = _settings.copyWith(
        mode: YearStartMode.custom,
        customStart: _dateOnly(customStart),
      );
      _goals = _sanitizeGoals(
        _goals,
        _resolveYearCycle(_currentToday, _settings),
      );
      _progressPageVersion++;
      _calendarPageVersion++;
    });

    unawaited(_persistState());
  }

  void _updateGoals(List<GoalEntry> goals) {
    setState(() {
      _goals = _sanitizeGoals(
        goals,
        _resolveYearCycle(_currentToday, _settings),
      );
      _progressPageVersion++;
      _calendarPageVersion++;
    });

    unawaited(_persistState());
  }

  void _updateTodoNotes(List<TodoNoteEntry> notes) {
    setState(() {
      _todoNotes = _sanitizeTodoNotes(notes);
    });

    unawaited(_persistState());
  }

  void _updateExpenses(List<ExpenseEntry> expenses) {
    setState(() {
      _expenses = _sanitizeExpenses(expenses);
    });

    unawaited(_persistState());
  }

  @override
  Widget build(BuildContext context) {
    final today = _currentToday;
    final cycle = _resolveYearCycle(today, _settings);
    final pages = [
      YearProgressPage(
        key: ValueKey(_progressPageVersion),
        today: today,
        settings: _settings,
        cycle: cycle,
        goals: _goals,
      ),
      YearCalendarPage(
        key: ValueKey(_calendarPageVersion),
        today: today,
        cycle: cycle,
        goals: _goals,
      ),
      SettingsPage(
        today: today,
        settings: _settings,
        cycle: cycle,
        goals: _goals,
        onModeChanged: _updateYearStartMode,
        onCustomStartChanged: _updateCustomStart,
        onGoalsChanged: _updateGoals,
      ),
    ];
    final titles = ['Year Completion', 'Year Calendar', 'Settings'];

    return Scaffold(
      appBar: AppBar(title: Text(titles[_selectedIndex])),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF00FF38), Color(0xFF111111)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Align(
                alignment: Alignment.bottomLeft,
                child: Text(
                  'Tracking App',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Text('Main'),
            ),
            _DrawerDestinationTile(
              icon: Icons.insights_outlined,
              selectedIcon: Icons.insights,
              label: 'Progress',
              selected: _selectedIndex == 0,
              onTap: () {
                Navigator.of(context).pop();
                setState(() {
                  _progressPageVersion++;
                  _selectedIndex = 0;
                });
              },
            ),
            _DrawerDestinationTile(
              icon: Icons.calendar_month_outlined,
              selectedIcon: Icons.calendar_month,
              label: 'Calendar',
              selected: _selectedIndex == 1,
              onTap: () {
                Navigator.of(context).pop();
                setState(() {
                  _calendarPageVersion++;
                  _selectedIndex = 1;
                });
              },
            ),
            _DrawerDestinationTile(
              icon: Icons.settings_outlined,
              selectedIcon: Icons.settings,
              label: 'Settings',
              selected: _selectedIndex == 2,
              onTap: () {
                Navigator.of(context).pop();
                setState(() {
                  _selectedIndex = 2;
                });
              },
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Text('Tools'),
            ),
            _DrawerDestinationTile(
              icon: Icons.checklist_outlined,
              selectedIcon: Icons.checklist,
              label: 'Todo notes',
              selected: false,
              onTap: () {
                Navigator.of(context).pop();
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (context) => TodoNotesPage(
                      today: today,
                      notes: _todoNotes,
                      onNotesChanged: _updateTodoNotes,
                    ),
                  ),
                );
              },
            ),
            _DrawerDestinationTile(
              icon: Icons.payments_outlined,
              selectedIcon: Icons.payments,
              label: 'Money expenses',
              selected: false,
              onTap: () {
                Navigator.of(context).pop();
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (context) => MoneyExpensesPage(
                      today: today,
                      expenses: _expenses,
                      onExpensesChanged: _updateExpenses,
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
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
    required this.goals,
  }) : _today = today;

  final DateTime? _today;
  final YearCycleSettings settings;
  final YearCycleRange cycle;
  final List<GoalEntry> goals;

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
    final sortedGoals = List<GoalEntry>.from(widget.goals)
      ..sort((a, b) => a.date.compareTo(b.date));

    return Center(
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Center(
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
                        title,
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
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
                                    Curves.easeOutCubic.transform(
                                      _controller.value,
                                    )
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
          if (sortedGoals.isNotEmpty) const SizedBox(height: 16),
          if (sortedGoals.isNotEmpty)
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: Column(
                  children: [
                    for (var index = 0; index < sortedGoals.length; index++)
                      Padding(
                        padding: EdgeInsets.only(
                          bottom: index == sortedGoals.length - 1 ? 0 : 12,
                        ),
                        child: _GoalProgressCard(
                          goal: sortedGoals[index],
                          now: now,
                          cycleStart: widget.cycle.start,
                          controller: _controller,
                          hasAnimationStarted: _hasAnimationStarted,
                          addTestKeys: index == 0,
                        ),
                      ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _GoalProgressCard extends StatelessWidget {
  const _GoalProgressCard({
    required this.goal,
    required this.now,
    required this.cycleStart,
    required this.controller,
    required this.hasAnimationStarted,
    required this.addTestKeys,
  });

  final GoalEntry goal;
  final DateTime now;
  final DateTime cycleStart;
  final AnimationController controller;
  final bool hasAnimationStarted;
  final bool addTestKeys;

  @override
  Widget build(BuildContext context) {
    final goalProgress = _goalCompletionRate(now, cycleStart, goal.date);
    final goalStatusLabel = _goalStatusLabel(now, goal);
    final accentColor = _goalAccentColor(goal);

    return Card(
      key: addTestKeys ? const Key('goal-progress-card') : null,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: AnimatedBuilder(
          animation: controller,
          builder: (context, child) {
            final animatedGoalProgress = hasAnimationStarted
                ? goalProgress * Curves.easeOutCubic.transform(controller.value)
                : 0.0;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  goal.name,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                Text(
                  'Goal date: ${_formatDate(goal.date)}',
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                const SizedBox(height: 16),
                LinearProgressIndicator(
                  key: addTestKeys ? const Key('goal-progress-bar') : null,
                  value: animatedGoalProgress,
                  minHeight: 18,
                  color: accentColor,
                  backgroundColor: const Color(0xFF4A4A4A),
                  borderRadius: BorderRadius.circular(999),
                ),
                const SizedBox(height: 12),
                Text(
                  '${(animatedGoalProgress * 100).toStringAsFixed(1)}%',
                  key: addTestKeys ? const Key('goal-progress-label') : null,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: accentColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(goalStatusLabel),
              ],
            );
          },
        ),
      ),
    );
  }
}

class YearCalendarPage extends StatefulWidget {
  const YearCalendarPage({
    super.key,
    required this.today,
    required this.cycle,
    required this.goals,
  });

  final DateTime today;
  final YearCycleRange cycle;
  final List<GoalEntry> goals;

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
              goals: widget.goals,
            ),
          );
        }),
      ),
    );
  }
}

class SettingsPage extends StatefulWidget {
  const SettingsPage({
    super.key,
    required this.today,
    required this.settings,
    required this.cycle,
    required this.goals,
    required this.onModeChanged,
    required this.onCustomStartChanged,
    required this.onGoalsChanged,
  });

  final DateTime today;
  final YearCycleSettings settings;
  final YearCycleRange cycle;
  final List<GoalEntry> goals;
  final ValueChanged<YearStartMode> onModeChanged;
  final ValueChanged<DateTime> onCustomStartChanged;
  final ValueChanged<List<GoalEntry>> onGoalsChanged;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                'Year Start',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              subtitle: Text(
                widget.settings.mode == YearStartMode.normal
                    ? 'Normal (January 1 to December 31)'
                    : 'Custom from ${_formatDate(widget.settings.customStart ?? widget.today)}',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (context) => YearStartSettingsPage(
                      today: widget.today,
                      settings: widget.settings,
                      onModeChanged: widget.onModeChanged,
                      onCustomStartChanged: widget.onCustomStartChanged,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                'Goal',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              subtitle: Text(
                widget.goals.isEmpty
                    ? 'No goals set'
                    : '${widget.goals.length} goal${widget.goals.length == 1 ? '' : 's'} configured',
                key: const Key('current-goal-summary'),
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (context) => GoalSettingsPage(
                      today: widget.today,
                      cycle: widget.cycle,
                      goals: widget.goals,
                      onGoalsChanged: widget.onGoalsChanged,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

class YearStartSettingsPage extends StatelessWidget {
  const YearStartSettingsPage({
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

    return Scaffold(
      appBar: AppBar(title: const Text('Year Start')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
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
      ),
    );
  }
}

class GoalSettingsPage extends StatefulWidget {
  const GoalSettingsPage({
    super.key,
    required this.today,
    required this.cycle,
    required this.goals,
    required this.onGoalsChanged,
  });

  final DateTime today;
  final YearCycleRange cycle;
  final List<GoalEntry> goals;
  final ValueChanged<List<GoalEntry>> onGoalsChanged;

  @override
  State<GoalSettingsPage> createState() => _GoalSettingsPageState();
}

class _GoalSettingsPageState extends State<GoalSettingsPage> {
  late final TextEditingController _goalNameController;
  late DateTime _selectedGoalDate;
  late List<GoalEntry> _draftGoals;

  @override
  void initState() {
    super.initState();
    _goalNameController = TextEditingController();
    _selectedGoalDate = _clampDateToCycle(widget.today, widget.cycle);
    _draftGoals = List<GoalEntry>.from(widget.goals);
  }

  @override
  void didUpdateWidget(covariant GoalSettingsPage oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (!_goalsEqual(oldWidget.goals, widget.goals) ||
        oldWidget.cycle.start != widget.cycle.start ||
        oldWidget.cycle.displayEnd != widget.cycle.displayEnd) {
      final cycle = widget.cycle;
      _draftGoals = _sanitizeGoals(widget.goals, cycle);
      _selectedGoalDate = _clampDateToCycle(widget.today, cycle);
    }
  }

  @override
  void dispose() {
    _goalNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sortedDraftGoals = List<GoalEntry>.from(_draftGoals)
      ..sort((a, b) => a.date.compareTo(b.date));

    return Scaffold(
      appBar: AppBar(title: const Text('Goal')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Add one or more goals with a name and date. New goals are staged with + and only saved when you tap Save changes.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    key: const Key('goal-name-field'),
                    controller: _goalNameController,
                    decoration: const InputDecoration(
                      labelText: 'Goal name',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('New goal date'),
                    subtitle: Text(_formatDate(_selectedGoalDate)),
                    trailing: FilledButton.tonal(
                      onPressed: () async {
                        final pickedDate = await showDatePicker(
                          context: context,
                          initialDate: _selectedGoalDate,
                          firstDate: widget.cycle.start,
                          lastDate: widget.cycle.displayEnd,
                        );

                        if (pickedDate != null) {
                          setState(() {
                            _selectedGoalDate = _dateOnly(pickedDate);
                          });
                        }
                      },
                      child: const Text('Select goal date'),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      FilledButton(
                        key: const Key('add-goal-button'),
                        onPressed: () {
                          final goalName = _goalNameController.text.trim();

                          if (goalName.isEmpty) {
                            return;
                          }

                          setState(() {
                            _draftGoals = [
                              ..._draftGoals,
                              GoalEntry(
                                name: goalName,
                                date: _dateOnly(_selectedGoalDate),
                              ),
                            ];
                            _goalNameController.clear();
                            _selectedGoalDate = _clampDateToCycle(
                              widget.today,
                              widget.cycle,
                            );
                          });
                        },
                        child: const Icon(Icons.add),
                      ),
                      const SizedBox(width: 12),
                      if (_draftGoals.isNotEmpty)
                        TextButton(
                          key: const Key('clear-goals-button'),
                          onPressed: () {
                            setState(() {
                              _draftGoals = <GoalEntry>[];
                            });
                          },
                          child: const Text('Clear all'),
                        ),
                    ],
                  ),
                  if (sortedDraftGoals.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(
                      'Staged goals',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    ...sortedDraftGoals.map(
                      (goal) => ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(goal.name),
                        subtitle: Text(_formatDate(goal.date)),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () {
                            setState(() {
                              _draftGoals = _removeFirstMatchingGoal(
                                _draftGoals,
                                goal,
                              );
                            });
                          },
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      key: const Key('save-goals-button'),
                      onPressed: () {
                        final sanitizedGoals = _sanitizeGoals(
                          _draftGoals,
                          widget.cycle,
                        );
                        widget.onGoalsChanged(sanitizedGoals);
                        Navigator.of(context).pop();
                      },
                      child: const Text('Save changes'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DrawerDestinationTile extends StatelessWidget {
  const _DrawerDestinationTile({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(selected ? selectedIcon : icon),
      title: Text(label),
      selected: selected,
      onTap: onTap,
    );
  }
}

class TodoNotesPage extends StatefulWidget {
  const TodoNotesPage({
    super.key,
    required this.today,
    required this.notes,
    required this.onNotesChanged,
  });

  final DateTime today;
  final List<TodoNoteEntry> notes;
  final ValueChanged<List<TodoNoteEntry>> onNotesChanged;

  @override
  State<TodoNotesPage> createState() => _TodoNotesPageState();
}

class _TodoNotesPageState extends State<TodoNotesPage> {
  late List<TodoNoteEntry> _draftNotes;

  @override
  void initState() {
    super.initState();
    _draftNotes = List<TodoNoteEntry>.from(widget.notes);
  }

  @override
  void didUpdateWidget(covariant TodoNotesPage oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (!_todoNotesEqual(oldWidget.notes, widget.notes)) {
      _draftNotes = List<TodoNoteEntry>.from(widget.notes);
    }
  }

  Future<void> _openAddNoteDialog() async {
    final titleController = TextEditingController();

    final shouldAdd = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('New todo note'),
          content: TextField(
            controller: titleController,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'Note title',
              border: OutlineInputBorder(),
            ),
            onSubmitted: (_) => Navigator.of(dialogContext).pop(true),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Add'),
            ),
          ],
        );
      },
    );

    if (shouldAdd != true) {
      titleController.dispose();
      return;
    }

    final title = titleController.text.trim();
    titleController.dispose();
    if (title.isEmpty) {
      return;
    }

    final updatedNotes = [
      ..._draftNotes,
      TodoNoteEntry(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        title: title,
        completed: false,
        createdAt: widget.today,
      ),
    ];

    setState(() {
      _draftNotes = updatedNotes;
    });
    widget.onNotesChanged(_sanitizeTodoNotes(updatedNotes));
  }

  @override
  Widget build(BuildContext context) {
    final completedCount = _draftNotes.where((note) => note.completed).length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Todo Notes'),
        actions: [
          IconButton(
            key: const Key('add-todo-note-button'),
            tooltip: 'Add note',
            icon: const Icon(Icons.add),
            onPressed: _openAddNoteDialog,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Text(
                'Completed: $completedCount • ${_draftNotes.length} note${_draftNotes.length == 1 ? '' : 's'}',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (_draftNotes.isNotEmpty)
            ..._draftNotes.map(
              (note) => Card(
                child: CheckboxListTile(
                  value: note.completed,
                  title: Text(note.title),
                  subtitle: Text('Added ${_formatDate(note.createdAt)}'),
                  secondary: IconButton(
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () {
                      final updatedNotes = _draftNotes
                          .where((item) => item.id != note.id)
                          .toList();
                      setState(() {
                        _draftNotes = updatedNotes;
                      });
                      widget.onNotesChanged(_sanitizeTodoNotes(updatedNotes));
                    },
                  ),
                  onChanged: (value) {
                    final updatedNotes = _draftNotes
                        .map(
                          (item) => item.id == note.id
                              ? item.copyWith(completed: value ?? false)
                              : item,
                        )
                        .toList();
                    setState(() {
                      _draftNotes = updatedNotes;
                    });
                    widget.onNotesChanged(_sanitizeTodoNotes(updatedNotes));
                  },
                ),
              ),
            )
          else
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Text(
                  'No todo notes yet.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class MoneyExpensesPage extends StatefulWidget {
  const MoneyExpensesPage({
    super.key,
    required this.today,
    required this.expenses,
    required this.onExpensesChanged,
  });

  final DateTime today;
  final List<ExpenseEntry> expenses;
  final ValueChanged<List<ExpenseEntry>> onExpensesChanged;

  @override
  State<MoneyExpensesPage> createState() => _MoneyExpensesPageState();
}

class _MoneyExpensesPageState extends State<MoneyExpensesPage> {
  late List<ExpenseEntry> _draftExpenses;

  @override
  void initState() {
    super.initState();
    _draftExpenses = List<ExpenseEntry>.from(widget.expenses);
  }

  @override
  void didUpdateWidget(covariant MoneyExpensesPage oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (!_expensesEqual(oldWidget.expenses, widget.expenses)) {
      _draftExpenses = List<ExpenseEntry>.from(widget.expenses);
    }
  }

  Future<void> _openAddExpenseDialog() async {
    final titleController = TextEditingController();
    final amountController = TextEditingController();
    DateTime selectedDate = _dateOnly(widget.today);

    final shouldAdd = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('New expense'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: titleController,
                      autofocus: true,
                      decoration: const InputDecoration(
                        labelText: 'Expense title',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: amountController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Amount',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Date'),
                      subtitle: Text(_formatDate(selectedDate)),
                      trailing: TextButton(
                        onPressed: () async {
                          final pickedDate = await showDatePicker(
                            context: dialogContext,
                            initialDate: selectedDate,
                            firstDate: DateTime(2000),
                            lastDate: DateTime(2100),
                          );

                          if (pickedDate != null) {
                            setDialogState(() {
                              selectedDate = _dateOnly(pickedDate);
                            });
                          }
                        },
                        child: const Text('Pick date'),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(dialogContext).pop(true),
                  child: const Text('Add'),
                ),
              ],
            );
          },
        );
      },
    );

    if (shouldAdd != true) {
      titleController.dispose();
      amountController.dispose();
      return;
    }

    final title = titleController.text.trim();
    final amount = double.tryParse(amountController.text.trim());
    titleController.dispose();
    amountController.dispose();
    if (title.isEmpty || amount == null) {
      return;
    }

    final updatedExpenses = [
      ..._draftExpenses,
      ExpenseEntry(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        title: title,
        amount: amount,
        date: selectedDate,
      ),
    ];

    setState(() {
      _draftExpenses = updatedExpenses;
    });
    widget.onExpensesChanged(_sanitizeExpenses(updatedExpenses));
  }

  @override
  Widget build(BuildContext context) {
    final totalSpent = _draftExpenses.fold<double>(
      0,
      (sum, expense) => sum + expense.amount,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Money Expenses'),
        actions: [
          IconButton(
            key: const Key('add-expense-button'),
            tooltip: 'Add expense',
            icon: const Icon(Icons.add),
            onPressed: _openAddExpenseDialog,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Text(
                'Total: ${totalSpent.toStringAsFixed(2)} • ${_draftExpenses.length} expense${_draftExpenses.length == 1 ? '' : 's'}',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (_draftExpenses.isNotEmpty)
            ..._draftExpenses.map(
              (expense) => Card(
                child: ListTile(
                  title: Text(expense.title),
                  subtitle: Text(
                    '${_formatDate(expense.date)} • ${expense.amount.toStringAsFixed(2)}',
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () {
                      final updatedExpenses = _draftExpenses
                          .where((item) => item.id != expense.id)
                          .toList();
                      setState(() {
                        _draftExpenses = updatedExpenses;
                      });
                      widget.onExpensesChanged(
                        _sanitizeExpenses(updatedExpenses),
                      );
                    },
                  ),
                ),
              ),
            )
          else
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Text(
                  'No expenses tracked yet.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _MonthCard extends StatelessWidget {
  const _MonthCard({
    required this.month,
    required this.year,
    required this.today,
    required this.cycle,
    required this.goals,
  });

  final int month;
  final int year;
  final DateTime today;
  final YearCycleRange cycle;
  final List<GoalEntry> goals;

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
              final isGoalDate =
                  isInCycle &&
                  day != null &&
                  _goalForDate(goals, DateTime(year, month, day)) != null;
              final goalForDay = day == null
                  ? null
                  : _goalForDate(goals, DateTime(year, month, day));
              final goalAccentColor = goalForDay == null
                  ? null
                  : _goalAccentColor(goalForDay);
              final isPastDay =
                  isInCycle &&
                  cellDate != null &&
                  cellDate.isBefore(todayDate) &&
                  !isToday &&
                  !isGoalDate;

              return Center(
                child: Container(
                  key: isGoalDate ? const Key('goal-calendar-date') : null,
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: day == null
                        ? Colors.transparent
                        : !isInCycle
                        ? Colors.transparent
                        : isGoalDate
                        ? goalAccentColor!.withValues(alpha: 0.28)
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
                          : isGoalDate
                          ? goalAccentColor!
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

double _goalCompletionRate(
  DateTime today,
  DateTime cycleStart,
  DateTime goalDate,
) {
  final start = _dateOnly(cycleStart);
  final end = _dateOnly(goalDate);
  final current = _dateOnly(today);
  final totalDays = end.difference(start).inDays;

  if (totalDays <= 0) {
    return !current.isBefore(end) ? 1.0 : 0.0;
  }

  final elapsedDays = current.difference(start).inDays;
  return (elapsedDays / totalDays).clamp(0.0, 1.0);
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

String _goalStatusLabel(DateTime today, GoalEntry goal) {
  final current = _dateOnly(today);
  final goalDate = _dateOnly(goal.date);

  if (current.isAfter(goalDate)) {
    return 'Goal date passed ${current.difference(goalDate).inDays} days ago.';
  }

  if (current == goalDate) {
    return 'Goal date is today.';
  }

  return '${goalDate.difference(current).inDays} days until this goal.';
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

DateTime _clampDateToCycle(DateTime date, YearCycleRange cycle) {
  final normalizedDate = _dateOnly(date);
  final cycleStart = _dateOnly(cycle.start);
  final cycleEnd = _dateOnly(cycle.displayEnd);

  if (normalizedDate.isBefore(cycleStart)) {
    return cycleStart;
  }

  if (normalizedDate.isAfter(cycleEnd)) {
    return cycleEnd;
  }

  return normalizedDate;
}

List<GoalEntry> _sanitizeGoals(List<GoalEntry> goals, YearCycleRange cycle) {
  final sanitizedGoals = <GoalEntry>[];
  final seenKeys = <String>{};

  for (final goal in goals) {
    final trimmedName = goal.name.trim();
    final normalizedDate = _dateOnly(goal.date);
    if (trimmedName.isEmpty) {
      continue;
    }

    if (normalizedDate.isBefore(_dateOnly(cycle.start)) ||
        normalizedDate.isAfter(_dateOnly(cycle.displayEnd))) {
      continue;
    }

    final dedupeKey =
        '${trimmedName.toLowerCase()}-${normalizedDate.toIso8601String()}';
    if (seenKeys.contains(dedupeKey)) {
      continue;
    }

    seenKeys.add(dedupeKey);
    sanitizedGoals.add(goal.copyWith(name: trimmedName, date: normalizedDate));
  }

  sanitizedGoals.sort((a, b) => a.date.compareTo(b.date));
  return sanitizedGoals;
}

List<TodoNoteEntry> _sanitizeTodoNotes(List<TodoNoteEntry> notes) {
  final sanitizedNotes = <TodoNoteEntry>[];
  final seenIds = <String>{};

  for (final note in notes) {
    final trimmedTitle = note.title.trim();
    if (trimmedTitle.isEmpty || seenIds.contains(note.id)) {
      continue;
    }

    seenIds.add(note.id);
    sanitizedNotes.add(
      note.copyWith(title: trimmedTitle, createdAt: _dateOnly(note.createdAt)),
    );
  }

  return sanitizedNotes;
}

List<ExpenseEntry> _sanitizeExpenses(List<ExpenseEntry> expenses) {
  final sanitizedExpenses = <ExpenseEntry>[];
  final seenIds = <String>{};

  for (final expense in expenses) {
    final trimmedTitle = expense.title.trim();
    final normalizedAmount = double.parse(expense.amount.toStringAsFixed(2));
    if (trimmedTitle.isEmpty ||
        normalizedAmount <= 0 ||
        seenIds.contains(expense.id)) {
      continue;
    }

    seenIds.add(expense.id);
    sanitizedExpenses.add(
      expense.copyWith(
        title: trimmedTitle,
        amount: normalizedAmount,
        date: _dateOnly(expense.date),
      ),
    );
  }

  return sanitizedExpenses;
}

List<TodoNoteEntry> _decodeTodoNotes(String? payload) {
  if (payload == null || payload.trim().isEmpty) {
    return <TodoNoteEntry>[];
  }

  try {
    final decoded = jsonDecode(payload);
    if (decoded is! List) {
      return <TodoNoteEntry>[];
    }

    return decoded
        .whereType<Map>()
        .map((item) {
          final id = item['id'];
          final title = item['title'];
          final completed = item['completed'];
          final createdAtValue = item['createdAt'];

          if (id is! String || title is! String || createdAtValue is! String) {
            return null;
          }

          final createdAt = DateTime.tryParse(createdAtValue);
          if (createdAt == null) {
            return null;
          }

          return TodoNoteEntry(
            id: id,
            title: title,
            completed: completed is bool ? completed : false,
            createdAt: createdAt,
          );
        })
        .whereType<TodoNoteEntry>()
        .toList();
  } catch (_) {
    return <TodoNoteEntry>[];
  }
}

List<ExpenseEntry> _decodeExpenses(String? payload) {
  if (payload == null || payload.trim().isEmpty) {
    return <ExpenseEntry>[];
  }

  try {
    final decoded = jsonDecode(payload);
    if (decoded is! List) {
      return <ExpenseEntry>[];
    }

    return decoded
        .whereType<Map>()
        .map((item) {
          final id = item['id'];
          final title = item['title'];
          final amountValue = item['amount'];
          final dateValue = item['date'];

          if (id is! String || title is! String || dateValue is! String) {
            return null;
          }

          final parsedAmount = amountValue is num
              ? amountValue.toDouble()
              : double.tryParse(amountValue?.toString() ?? '');
          final parsedDate = DateTime.tryParse(dateValue);
          if (parsedAmount == null || parsedDate == null) {
            return null;
          }

          return ExpenseEntry(
            id: id,
            title: title,
            amount: parsedAmount,
            date: parsedDate,
          );
        })
        .whereType<ExpenseEntry>()
        .toList();
  } catch (_) {
    return <ExpenseEntry>[];
  }
}

List<GoalEntry> _removeFirstMatchingGoal(
  List<GoalEntry> goals,
  GoalEntry target,
) {
  var removed = false;
  final updatedGoals = <GoalEntry>[];

  for (final goal in goals) {
    final isMatch =
        !removed &&
        goal.name == target.name &&
        _dateOnly(goal.date) == _dateOnly(target.date);
    if (isMatch) {
      removed = true;
      continue;
    }
    updatedGoals.add(goal);
  }

  return updatedGoals;
}

bool _goalsEqual(List<GoalEntry> a, List<GoalEntry> b) {
  if (a.length != b.length) {
    return false;
  }

  for (var i = 0; i < a.length; i++) {
    if (a[i].name != b[i].name ||
        _dateOnly(a[i].date) != _dateOnly(b[i].date)) {
      return false;
    }
  }

  return true;
}

bool _todoNotesEqual(List<TodoNoteEntry> a, List<TodoNoteEntry> b) {
  if (a.length != b.length) {
    return false;
  }

  for (var i = 0; i < a.length; i++) {
    if (a[i].id != b[i].id ||
        a[i].title != b[i].title ||
        a[i].completed != b[i].completed ||
        _dateOnly(a[i].createdAt) != _dateOnly(b[i].createdAt)) {
      return false;
    }
  }

  return true;
}

bool _expensesEqual(List<ExpenseEntry> a, List<ExpenseEntry> b) {
  if (a.length != b.length) {
    return false;
  }

  for (var i = 0; i < a.length; i++) {
    if (a[i].id != b[i].id ||
        a[i].title != b[i].title ||
        a[i].amount != b[i].amount ||
        _dateOnly(a[i].date) != _dateOnly(b[i].date)) {
      return false;
    }
  }

  return true;
}

String _formatDate(DateTime date) {
  return '${_monthNames[date.month - 1]} ${date.day}, ${date.year}';
}

Color _goalAccentColor(GoalEntry goal) {
  final paletteIndex =
      (goal.name.toLowerCase().hashCode ^ goal.date.toIso8601String().hashCode)
          .abs() %
      _goalAccentPalette.length;
  return _goalAccentPalette[paletteIndex];
}

GoalEntry? _goalForDate(List<GoalEntry> goals, DateTime date) {
  final normalizedDate = _dateOnly(date);

  for (final goal in goals) {
    if (_dateOnly(goal.date) == normalizedDate) {
      return goal;
    }
  }

  return null;
}
