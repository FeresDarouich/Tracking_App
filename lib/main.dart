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
        seedColor: const Color(0xFF1E88E5),
        brightness: Brightness.light,
      ),
      scaffoldBackgroundColor: const Color(0xFFF6F8FB),
      useMaterial3: true,
    );

    return MaterialApp(
      title: 'Year Progress',
      theme: theme,
      home: const YearProgressPage(),
    );
  }
}

class YearProgressPage extends StatelessWidget {
  const YearProgressPage({super.key, DateTime? today}) : _today = today;

  final DateTime? _today;

  @override
  Widget build(BuildContext context) {
    final now = _today ?? DateTime.now();
    final progress = _yearCompletionRate(now);
    final percentageLabel = '${(progress * 100).toStringAsFixed(1)}%';
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
                    ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: LinearProgressIndicator(
                        key: const Key('year-progress-bar'),
                        value: progress,
                        minHeight: 24,
                        backgroundColor: const Color(0xFFDCE7F3),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      percentageLabel,
                      key: const Key('year-progress-label'),
                      style: Theme.of(context).textTheme.displaySmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
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
