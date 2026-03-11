import 'package:fitai_analyzer/models/fitness_data.dart';
import 'package:fitai_analyzer/providers/auth_notifier.dart';
import 'package:fitai_analyzer/providers/data_sync_notifier.dart';
import 'package:fitai_analyzer/ui/widgets/error_dialog.dart';
import 'package:fitai_analyzer/utils/demo_fitness_data.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authNotifierProvider);
    final garminAsync = ref.watch(garminDataStreamProvider);
    final healthAsync = ref.watch(healthDataStreamProvider);

    ref.listen(garminDataStreamProvider, (prev, next) {
      next.whenOrNull(
        error: (e, _) {
          if (context.mounted) showErrorDialog(context, e.toString());
        },
      );
    });
    ref.listen(healthDataStreamProvider, (prev, next) {
      next.whenOrNull(
        error: (e, _) {
          if (context.mounted) showErrorDialog(context, e.toString());
        },
      );
    });

    return Scaffold(
      appBar: AppBar(
        title: Hero(
          tag: 'appTitle',
          child: Material(
            color: Colors.transparent,
            child: Text(
              'Dashboard',
              style: Theme.of(context).appBarTheme.titleTextStyle,
            ),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () =>
                ref.read(authNotifierProvider.notifier).signOut(),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (kUseDemoData)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.tertiaryContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.science, size: 20, color: Theme.of(context).colorScheme.onTertiaryContainer),
                      const SizedBox(width: 8),
                      Text(
                        'Dati simulati (Health Connect / Garmin / Apple Health)',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onTertiaryContainer,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            _WelcomeCard(userName: authState.user?.email ?? 'Utente'),
            const SizedBox(height: 24),
            garminAsync.when(
              data: (data) => _StepsChartCard(data: data),
              loading: () => const _ChartSkeleton(),
              error: (e, _) => _ErrorCard(message: e.toString()),
            ),
            const SizedBox(height: 16),
            healthAsync.when(
              data: (data) => _CaloriesChartCard(data: data),
              loading: () => const _ChartSkeleton(),
              error: (e, _) => _ErrorCard(message: e.toString()),
            ),
          ],
        ),
      ),
    );
  }
}

class _WelcomeCard extends StatelessWidget {
  const _WelcomeCard({required this.userName});

  final String userName;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOut,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Benvenuto!',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 4),
          Text(
            userName,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                ),
          ),
        ],
      ),
    );
  }
}

class _StepsChartCard extends StatelessWidget {
  const _StepsChartCard({required this.data});

  final List<FitnessData> data;

  @override
  Widget build(BuildContext context) {
    final spots = data
        .asMap()
        .entries
        .map((e) => FlSpot(
              e.key.toDouble(),
              (e.value.steps ?? 0).toDouble(),
            ))
        .toList();

    return AnimatedContainer(
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeOut,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Passi (Garmin)',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 200,
            child: spots.isEmpty
                ? Center(
                    child: Text(
                      'Nessun dato. Connetti Garmin per sincronizzare.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  )
                : LineChart(
                    LineChartData(
                      gridData: FlGridData(show: true),
                      titlesData: FlTitlesData(show: false),
                      borderData: FlBorderData(show: false),
                      lineBarsData: [
                        LineChartBarData(
                          spots: spots,
                          isCurved: true,
                          color: Theme.of(context).colorScheme.primary,
                          barWidth: 2,
                          dotData: const FlDotData(show: true),
                          belowBarData: BarAreaData(
                            show: true,
                            color: Theme.of(context)
                                .colorScheme
                                .primary
                                .withValues(alpha: 0.1),
                          ),
                        ),
                      ],
                    ),
                    duration: const Duration(milliseconds: 300),
                  ),
          ),
        ],
      ),
    );
  }
}

class _CaloriesChartCard extends StatelessWidget {
  const _CaloriesChartCard({required this.data});

  final List<FitnessData> data;

  @override
  Widget build(BuildContext context) {
    final barGroups = data
        .asMap()
        .entries
        .map((e) => BarChartGroupData(
              x: e.key,
              barRods: [
                BarChartRodData(
                  toY: (e.value.calories ?? 0).toDouble(),
                  color: Theme.of(context).colorScheme.secondary,
                  width: 16,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(4),
                  ),
                ),
              ],
              showingTooltipIndicators: [0],
            ))
        .toList();

    return AnimatedContainer(
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeOut,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Calorie (Apple Health)',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 200,
            child: barGroups.isEmpty
                ? Center(
                    child: Text(
                      'Nessun dato. Connetti Apple Health per sincronizzare.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  )
                : BarChart(
                    BarChartData(
                      alignment: BarChartAlignment.spaceAround,
                      maxY: data.isEmpty
                          ? 100
                          : (data
                                  .map((d) => (d.calories ?? 0).toDouble())
                                  .reduce((a, b) => a > b ? a : b) *
                              1.2)
                              .clamp(100.0, double.infinity),
                      barTouchData: BarTouchData(enabled: true),
                      titlesData: FlTitlesData(show: false),
                      gridData: FlGridData(show: true),
                      borderData: FlBorderData(show: false),
                      barGroups: barGroups,
                    ),
                    swapAnimationDuration: const Duration(milliseconds: 300),
                  ),
          ),
        ],
      ),
    );
  }
}

class _ChartSkeleton extends StatelessWidget {
  const _ChartSkeleton();

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      height: 200,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        message,
        style: TextStyle(color: Theme.of(context).colorScheme.onErrorContainer),
      ),
    );
  }
}
