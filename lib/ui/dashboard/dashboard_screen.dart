import 'package:firebase_auth/firebase_auth.dart';
import 'package:fitai_analyzer/models/fitness_data.dart';
import 'package:fitai_analyzer/providers/auth_notifier.dart';
import 'package:fitai_analyzer/providers/data_sync_notifier.dart';
import 'package:fitai_analyzer/providers/providers.dart';
import 'package:fitai_analyzer/services/ai_prompt_service.dart';
import 'package:fitai_analyzer/services/gemini_api_key_service.dart';
import 'package:fitai_analyzer/services/gemini_service.dart';
import 'package:fitai_analyzer/services/strava_service.dart';
import 'package:fitai_analyzer/ui/theme/app_colors.dart';
import 'package:fitai_analyzer/ui/widgets/compact_activity_card.dart';
import 'package:fitai_analyzer/ui/widgets/error_dialog.dart';
import 'package:fitai_analyzer/ui/widgets/gemini_api_key_dialog.dart';
import 'package:fitai_analyzer/ui/widgets/strava_activity_card.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Filtro data selezionata: null = tutte.
final selectedDateFilterProvider = StateProvider<String?>((ref) => null);

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  Future<void> _onSyncStrava(BuildContext context, WidgetRef ref) async {
    await ref.read(authNotifierProvider.notifier).startOAuth(
      'strava',
      onSuccess: () {
        ref.invalidate(healthDataStreamProvider);
        ref.read(selectedTabIndexProvider.notifier).state = 1;
      },
    );
  }

  Future<void> _onAnalisiAI(BuildContext context, WidgetRef ref) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      if (context.mounted) {
        showErrorDialog(context, 'Utente non autenticato.');
      }
      return;
    }

    final apiKeyService = ref.read(geminiApiKeyServiceProvider);
    if (!await apiKeyService.hasValidKey()) {
      if (!context.mounted) return;
      final saved = await showGeminiApiKeyDialog(context, ref);
      if (!saved || !context.mounted) return;
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
    final stravaConnected = ref.watch(stravaConnectedProvider).valueOrNull ?? false;

    ref.listen(healthDataStreamProvider, (prev, next) {
      next.whenOrNull(
        error: (e, _) {
          if (context.mounted) showErrorDialog(context, e.toString());
        },
      );
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('Allenamenti'),
      ),
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _WelcomeCard(userName: authState.user?.email ?? 'Utente'),
                    const SizedBox(height: 16),
                    _AnalisiAIButton(
                      onTap: () => _onAnalisiAI(context, ref),
                    ),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
                child: healthAsync.when(
                  data: (data) => _CaloriesChartCard(
                    data: data,
                    isStravaConnected: stravaConnected,
                    onSyncTap: () => _onSyncStrava(context, ref),
                  ),
                  loading: () => const _ChartSkeleton(),
                  error: (e, _) => _ErrorCard(message: e.toString()),
                ),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 8)),
            SliverToBoxAdapter(
              child: _ActivitiesSection(
                stravaConnected: stravaConnected,
                onSyncTap: () => _onSyncStrava(context, ref),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActivitiesSection extends ConsumerWidget {
  const _ActivitiesSection({
    required this.stravaConnected,
    required this.onSyncTap,
  });

  final bool stravaConnected;
  final VoidCallback onSyncTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final byDate = ref.watch(activitiesByDateProvider);
    final dates = ref.watch(activityDatesProvider);
    final selectedDate = ref.watch(selectedDateFilterProvider);

    if (byDate.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: _EmptyActivitiesCard(
          isStravaConnected: stravaConnected,
          onSyncTap: onSyncTap,
        ),
      );
    }

    final displayDates = selectedDate != null ? [selectedDate] : dates;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'Date',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 44,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            children: [
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: _DateChip(
                  label: 'Tutti',
                  isSelected: selectedDate == null,
                  onTap: () => ref.read(selectedDateFilterProvider.notifier).state = null,
                ),
              ),
              ...dates.map((dateKey) {
                final label = formatDateForDisplay(dateKey);
                final isSelected = selectedDate == dateKey;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: _DateChip(
                    label: label,
                    isSelected: isSelected,
                    onTap: () {
                      ref.read(selectedDateFilterProvider.notifier).state =
                          isSelected ? null : dateKey;
                    },
                  ),
                );
              }),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'Allenamenti',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(height: 12),
        ...displayDates.map((dateKey) {
          final activities = byDate[dateKey] ?? [];
          if (activities.isEmpty) return const SizedBox.shrink();
          final label = formatDateForDisplay(dateKey);
          return Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    label,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                ...activities.map((a) {
                  final activity = StravaActivity.fromFitnessData(a);
                  return CompactActivityCard(
                    activity: a,
                    onTap: activity.id > 0
                        ? () => _showStravaDetailDialog(context, activity.id)
                        : null,
                  );
                }),
              ],
            ),
          );
        }),
      ],
    );
  }

  void _showStravaDetailDialog(BuildContext context, int activityId) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => _StravaDetailLoadingDialog(activityId: activityId),
    );
  }
}

class _DateChip extends StatelessWidget {
  const _DateChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: isSelected
                ? theme.colorScheme.primary
                : theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSelected
                  ? theme.colorScheme.primary
                  : theme.colorScheme.outline.withValues(alpha: 0.3),
            ),
          ),
          child: Text(
            label,
            style: theme.textTheme.labelLarge?.copyWith(
              color: isSelected
                  ? theme.colorScheme.onPrimary
                  : theme.colorScheme.onSurfaceVariant,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyActivitiesCard extends StatelessWidget {
  const _EmptyActivitiesCard({
    required this.isStravaConnected,
    required this.onSyncTap,
  });

  final bool isStravaConnected;
  final VoidCallback onSyncTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: theme.colorScheme.outline.withValues(alpha: 0.2),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Icon(
              Icons.directions_bike_outlined,
              size: 48,
              color: theme.colorScheme.outline,
            ),
            const SizedBox(height: 16),
            Text(
              isStravaConnected
                  ? 'Nessuna attività. Sincronizza per caricare gli allenamenti.'
                  : 'Connetti Strava per sincronizzare le tue attività.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            if (isStravaConnected) ...[
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: onSyncTap,
                icon: const Icon(Icons.sync, size: 18),
                label: const Text('Sincronizza'),
              ),
            ],
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
      color: AppColors.transparent,
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
            color: AppColors.shadowLight(0.05),
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
  const _CaloriesChartCard({
    required this.data,
    required this.isStravaConnected,
    required this.onSyncTap,
  });

  final List<FitnessData> data;
  final bool isStravaConnected;
  final VoidCallback onSyncTap;

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
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          isStravaConnected
                              ? 'Nessun dato. Sincronizza per caricare le attività.'
                              : 'Nessun dato. Connetti Strava per sincronizzare.',
                          style: Theme.of(context).textTheme.bodySmall,
                          textAlign: TextAlign.center,
                        ),
                        if (isStravaConnected) ...[
                          const SizedBox(height: 12),
                          FilledButton.icon(
                            onPressed: onSyncTap,
                            icon: const Icon(Icons.sync, size: 18),
                            label: const Text('Sincronizza'),
                          ),
                        ],
                      ],
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
