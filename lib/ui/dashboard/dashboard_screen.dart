import 'package:firebase_auth/firebase_auth.dart';
import 'package:fitai_analyzer/models/fitness_data.dart';
import 'package:fitai_analyzer/providers/auth_notifier.dart';
import 'package:fitai_analyzer/providers/data_sync_notifier.dart';
import 'package:fitai_analyzer/services/ai_prompt_service.dart';
import 'package:fitai_analyzer/services/gemini_service.dart';
import 'package:fitai_analyzer/services/strava_service.dart';
import 'package:fitai_analyzer/ui/widgets/error_dialog.dart';
import 'package:fitai_analyzer/ui/widgets/strava_activity_card.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  Future<void> _onAnalisiAI(BuildContext context, WidgetRef ref) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      if (context.mounted) {
        showErrorDialog(context, 'Utente non autenticato.');
      }
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const AlertDialog(
        content: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 16),
            Text('Analisi AI in corso...'),
          ],
        ),
      ),
    );

    try {
      final contextStr = await ref.read(aiPromptServiceProvider).buildFullAIContext(uid);
      final response = await ref.read(geminiServiceProvider).analyzeFitnessContext(contextStr);

      if (context.mounted) {
        Navigator.of(context).pop(); // chiudi loading
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Analisi AI'),
            content: SingleChildScrollView(
              child: SelectableText(response),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Chiudi'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.of(context).pop(); // chiudi loading
        showErrorDialog(context, e.toString());
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authNotifierProvider);
    final healthAsync = ref.watch(healthDataStreamProvider);

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
            _WelcomeCard(userName: authState.user?.email ?? 'Utente'),
            const SizedBox(height: 16),
            _AnalisiAIButton(
              onTap: () => _onAnalisiAI(context, ref),
            ),
            const SizedBox(height: 24),
            healthAsync.when(
              data: (data) => _CaloriesChartCard(data: data),
              loading: () => const _ChartSkeleton(),
              error: (e, _) => _ErrorCard(message: e.toString()),
            ),
            const SizedBox(height: 16),
            healthAsync.when(
              data: (data) {
                final stravaData = data.where((d) => d.source == 'strava').toList();
                return _StravaActivitiesCard(data: stravaData);
              },
              loading: () => const _ChartSkeleton(),
              error: (e, _) => _ErrorCard(message: e.toString()),
            ),
          ],
        ),
      ),
    );
  }
}

class _AnalisiAIButton extends StatelessWidget {
  const _AnalisiAIButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Theme.of(context).colorScheme.primary,
                Theme.of(context).colorScheme.primary.withValues(alpha: 0.8),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Icon(
                Icons.auto_awesome,
                color: Theme.of(context).colorScheme.onPrimary,
                size: 32,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Analisi AI',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            color: Theme.of(context).colorScheme.onPrimary,
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Piano settimanale personalizzato con Gemini',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.9),
                          ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                color: Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.8),
                size: 18,
              ),
            ],
          ),
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
            'Calorie',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 200,
            child: barGroups.isEmpty
                ? Center(
                    child: Text(
                      'Nessun dato. Connetti una fonte per sincronizzare.',
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
                    duration: const Duration(milliseconds: 300),
                  ),
          ),
        ],
      ),
    );
  }
}

class _StravaActivitiesCard extends StatelessWidget {
  const _StravaActivitiesCard({required this.data});

  final List<FitnessData> data;

  @override
  Widget build(BuildContext context) {
    final stravaData = data.where((d) => d.source == 'strava').toList()
      ..sort((a, b) => b.date.compareTo(a.date));
    final stravaWithDistance =
        stravaData.where((d) => (d.distanceKm ?? 0) > 0).toList();
    final barGroups = stravaWithDistance
        .asMap()
        .entries
        .map((e) => BarChartGroupData(
              x: e.key,
              barRods: [
                BarChartRodData(
                  toY: (e.value.distanceKm ?? 0).toDouble(),
                  color: const Color(0xFFFC4C02),
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
          Row(
            children: [
              const Icon(Icons.directions_bike,
                  color: Color(0xFFFC4C02), size: 24),
              const SizedBox(width: 8),
              Text(
                'Attività Strava',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 200,
            child: barGroups.isEmpty
                ? Center(
                    child: Text(
                      'Nessuna attività. Connetti Strava per sincronizzare.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  )
                : BarChart(
                    BarChartData(
                      alignment: BarChartAlignment.spaceAround,
                      maxY: stravaWithDistance.isEmpty
                          ? 10
                          : (stravaWithDistance
                                  .map((d) => (d.distanceKm ?? 0).toDouble())
                                  .reduce((a, b) => a > b ? a : b) *
                              1.2)
                              .clamp(10.0, double.infinity),
                      barTouchData: BarTouchData(enabled: true),
                      titlesData: FlTitlesData(show: false),
                      gridData: FlGridData(show: true),
                      borderData: FlBorderData(show: false),
                      barGroups: barGroups,
                    ),
                    duration: const Duration(milliseconds: 300),
                  ),
          ),
          if (stravaData.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                '${stravaData.length} attività • Totale ${(stravaData.fold<double>(0, (s, d) => s + (d.distanceKm ?? 0))).toStringAsFixed(1)} km',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Dettaglio attività',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                  ),
            ),
            const SizedBox(height: 8),
            ...stravaData.take(10).map((d) {
              final activity = StravaActivity.fromFitnessData(d);
              return StravaActivityCard(
                activity: activity,
                onTap: activity.id > 0
                    ? () => _showStravaDetailDialog(context, activity.id)
                    : null,
              );
            }),
          ],
        ],
      ),
    );
  }

  /// Carica dettaglio on-tap (calories, laps) — rispetta rate limit 100/15min
  void _showStravaDetailDialog(BuildContext context, int activityId) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => _StravaDetailLoadingDialog(activityId: activityId),
    );
  }
}

class _StravaDetailLoadingDialog extends ConsumerStatefulWidget {
  const _StravaDetailLoadingDialog({required this.activityId});

  final int activityId;

  @override
  ConsumerState<_StravaDetailLoadingDialog> createState() =>
      _StravaDetailLoadingDialogState();
}

class _StravaDetailLoadingDialogState
    extends ConsumerState<_StravaDetailLoadingDialog> {
  StravaActivity? _detailed;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final act = await ref
          .read(stravaServiceProvider)
          .getDetailedActivity(widget.activityId);
      if (mounted) setState(() => _detailed = act);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return AlertDialog(
        title: const Text('Errore'),
        content: Text(_error!),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Chiudi'),
          ),
        ],
      );
    }
    if (_detailed != null) {
      return AlertDialog(
        title: Text(_detailed!.name),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              StravaActivityCard(activity: _detailed!),
              if (_detailed!.laps != null && _detailed!.laps!.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(
                  'Giri (${_detailed!.laps!.length})',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 8),
                ..._detailed!.laps!.take(5).map((lap) {
                  final m = lap is Map ? lap as Map<String, dynamic> : <String, dynamic>{};
                  final distM = (m['distance'] as num?)?.toDouble() ?? 0;
                  final speed = (m['average_speed'] as num?)?.toDouble();
                  final pace = speed != null && speed > 0
                      ? (1000 / 60 / speed).toStringAsFixed(1)
                      : '—';
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      'Lap ${m['lap_index'] ?? ''}: ${(distM / 1000).toStringAsFixed(2)} km • Pace $pace min/km',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  );
                }),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Chiudi'),
          ),
        ],
      );
    }
    return const AlertDialog(
      content: SizedBox(
        width: 80,
        height: 80,
        child: Center(child: CircularProgressIndicator()),
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
