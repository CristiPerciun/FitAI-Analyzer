import 'package:fitai_analyzer/providers/data_sync_notifier.dart';
import 'package:fitai_analyzer/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Widget che mostra Passi, Punteggio Sonno e Body Battery da daily_health (Garmin).
/// Stile coerente con Longevity Path e Weekly Sprint.
class GarminDailyStats extends ConsumerWidget {
  const GarminDailyStats({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dailyHealth = ref.watch(dailyHealthStreamProvider).valueOrNull ?? [];
    final todayStr = DateTime.now().toIso8601String().split('T')[0];
    final todayData = dailyHealth
        .where((d) => (d['date'] as String?) == todayStr)
        .firstOrNull;

    final steps = _extractSteps(todayData);
    final sleepScore = _extractSleepScore(todayData);
    final bodyBattery = _extractBodyBattery(todayData);
    final hasData = steps != null || sleepScore != null || bodyBattery != null;

    final theme = Theme.of(context);

    return Material(
      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: theme.colorScheme.primary.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.garminBlue.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.watch,
                    color: AppColors.garminBlue,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Dati Garmin',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    Text(
                      'Passi, Sonno, Body Battery',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 20),
            if (hasData)
              Row(
                children: [
                  Expanded(
                    child: _StatChip(
                      icon: Icons.directions_walk,
                      label: 'Passi',
                      value: steps != null ? _formatSteps(steps) : '—',
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  Expanded(
                    child: _StatChip(
                      icon: Icons.bedtime,
                      label: 'Sonno',
                      value: sleepScore != null ? '$sleepScore' : '—',
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  Expanded(
                    child: _StatChip(
                      icon: Icons.battery_charging_full,
                      label: 'Body Battery',
                      value: bodyBattery != null ? '$bodyBattery' : '—',
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ],
              )
            else
              Text(
                'Trascina per aggiornare i dati Garmin',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: AppColors.hintMedium,
                  fontStyle: FontStyle.italic,
                ),
              ),
          ],
        ),
      ),
    );
  }

  static int? _extractSteps(Map<String, dynamic>? data) {
    if (data == null) return null;
    final stats = data['stats'] as Map<String, dynamic>?;
    if (stats == null) return null;
    final s = stats['totalSteps'] ?? stats['userSteps'];
    if (s == null) return null;
    return (s as num).toInt();
  }

  static int? _extractSleepScore(Map<String, dynamic>? data) {
    if (data == null) return null;
    final sleep = data['sleep'];
    if (sleep is! Map<String, dynamic>) return null;
    final score = sleep['sleepScore'] ??
        sleep['overallSleepScore'] ??
        sleep['wellnessSleepScore'] ??
        (sleep['sleepScores'] as Map<String, dynamic>?)?['overall'] ??
        (sleep['dailySleepDTO'] as Map<String, dynamic>?)?['sleepScore'];
    return score != null ? (score as num).toInt() : null;
  }

  static int? _extractBodyBattery(Map<String, dynamic>? data) {
    if (data == null) return null;
    // Da stats (get_stats include body battery)
    final stats = data['stats'] as Map<String, dynamic>?;
    if (stats != null) {
      final v = stats['bodyBatteryMostRecentValue'] ??
          stats['bodyBatteryChargedValue'] ??
          stats['bodyBatteryHighestValue'];
      if (v != null) return (v as num).toInt();
    }
    // Da body_battery (lista)
    final bb = data['body_battery'];
    if (bb is List && bb.isNotEmpty) {
      final first = bb.first;
      if (first is Map<String, dynamic>) {
        final v = first['bodyBatteryMostRecentValue'] ??
            first['bodyBatteryChargedValue'] ??
            first['value'];
        if (v != null) return (v as num).toInt();
      }
    }
    return null;
  }

  static String _formatSteps(int steps) {
    if (steps >= 1000) {
      return '${(steps / 1000).toStringAsFixed(1)}k';
    }
    return steps.toString();
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(height: 4),
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: color.withValues(alpha: 0.9),
              ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: color,
              ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
