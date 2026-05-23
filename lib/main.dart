import 'dart:async';

import 'package:flutter/material.dart';

void main() {
  runApp(const MyApp());
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
      theme: theme,
      home: const YearProgressPage(),
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

    return Scaffold(
      appBar: AppBar(title: const Text('Year Completion')),
      body: Center(
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
