import 'package:fitai_analyzer/providers/data_sync_notifier.dart';
import 'package:fitai_analyzer/theme/app_theme.dart';
import 'package:fitai_analyzer/ui/widgets/design/design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Widget che mostra Passi, Punteggio Sonno e Body Battery da daily_health (Garmin).
/// Stile coerente con il redesign (FitSoftCard + FitCardHeader).
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

    return FitSoftCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const FitIconBadge(icon: Icons.watch, tint: AppColors.garminBlue),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Dati Garmin',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.onSurface,
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
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: FitMetricDisplay(
                    align: CrossAxisAlignment.center,
                    valueFontSize: 22,
                    value: steps != null ? _formatSteps(steps) : '—',
                    caption: 'Passi',
                  ),
                ),
                Expanded(
                  child: FitMetricDisplay(
                    align: CrossAxisAlignment.center,
                    valueFontSize: 22,
                    value: sleepScore != null ? '$sleepScore' : '—',
                    caption: 'Sonno',
                  ),
                ),
                Expanded(
                  child: FitMetricDisplay(
                    align: CrossAxisAlignment.center,
                    valueFontSize: 22,
                    value: bodyBattery != null ? '$bodyBattery' : '—',
                    caption: 'Body Battery',
                  ),
                ),
              ],
            )
          else
            Text(
              'Trascina per aggiornare i dati Garmin',
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontStyle: FontStyle.italic,
              ),
            ),
        ],
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
    final score =
        sleep['sleepScore'] ??
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
      final v =
          stats['bodyBatteryMostRecentValue'] ??
          stats['bodyBatteryChargedValue'] ??
          stats['bodyBatteryHighestValue'];
      if (v != null) return (v as num).toInt();
    }
    // Da body_battery (lista)
    final bb = data['body_battery'];
    if (bb is List && bb.isNotEmpty) {
      final first = bb.first;
      if (first is Map<String, dynamic>) {
        final v =
            first['bodyBatteryMostRecentValue'] ??
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
