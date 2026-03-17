import 'package:fitai_analyzer/providers/data_sync_notifier.dart';
import 'package:fitai_analyzer/providers/providers.dart';
import 'package:fitai_analyzer/theme/app_card_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Header dinamico che mostra il "Carico di Longevità" odierno.
/// Passi da `daily_health` e calorie attività da `activities`.
class LongevityHeader extends ConsumerWidget {
  const LongevityHeader({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final package = ref.watch(longevityHomePackageProvider).valueOrNull;
    final activities = ref.watch(activitiesStreamProvider).valueOrNull ?? [];
    final dailyHealth = ref.watch(dailyHealthStreamProvider).valueOrNull ?? [];
    final todayStr = DateTime.now().toIso8601String().split('T')[0];

    final todayActivities = activities.where((d) {
      final key =
          '${d.date.year}-${d.date.month.toString().padLeft(2, '0')}-${d.date.day.toString().padLeft(2, '0')}';
      return key == todayStr;
    }).toList();

    double steps = 0;
    final todayDailyHealth = dailyHealth
        .where((d) => (d['date'] as String?) == todayStr)
        .firstOrNull;
    if (todayDailyHealth != null) {
      final stats = todayDailyHealth['stats'] as Map<String, dynamic>?;
      if (stats != null) {
        final s = stats['totalSteps'] ?? stats['userSteps'];
        if (s != null) steps = (s as num).toDouble();
      }
    }
    final caloriesFromActivities = todayActivities.fold<double>(
      0,
      (s, d) => s + (d.calories ?? 0),
    );

    // Fallback: calorie aggregate da daily_logs se lo stream attività è ancora vuoto.
    final caloriesBurned = caloriesFromActivities > 0
        ? caloriesFromActivities
        : (package?.today?.totalBurnedKcalForAggregation ?? 0);
    double caloriesIntake = 0;
    final todayNut = package?.today?.nutritionForAi;
    if (todayNut != null && todayNut.isNotEmpty) {
      final cal = todayNut['total_calories'] ?? todayNut['total_kcal'];
      caloriesIntake = (cal as num?)?.toDouble() ?? 0;
    }

    final theme = Theme.of(context);
    final cardTheme = theme.extension<AppCardTheme>();

    return Container(
      width: double.infinity,
      decoration:
          cardTheme?.gradientDecoration ??
          BoxDecoration(
            color: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(16),
          ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.today,
                  color: cardTheme?.contentColor ?? theme.colorScheme.primary,
                  size: 24,
                ),
                const SizedBox(width: 8),
                Text(
                  'Oggi',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color:
                        cardTheme?.contentColor ?? theme.colorScheme.onSurface,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Carico di Longevità',
              style: theme.textTheme.bodySmall?.copyWith(
                color:
                    cardTheme?.contentColorMuted ??
                    theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                _MetricChip(
                  icon: Icons.directions_walk,
                  label: 'Passi',
                  value: steps > 0 ? steps.toStringAsFixed(0) : '—',
                  color: cardTheme?.contentColor ?? theme.colorScheme.primary,
                ),
                const SizedBox(width: 16),
                _MetricChip(
                  icon: Icons.local_fire_department,
                  label: 'Bruciate',
                  value: caloriesBurned > 0
                      ? '${caloriesBurned.toStringAsFixed(0)} kcal'
                      : '—',
                  color: cardTheme?.contentColor ?? theme.colorScheme.primary,
                ),
                const SizedBox(width: 16),
                _MetricChip(
                  icon: Icons.restaurant,
                  label: 'Assunte',
                  value: caloriesIntake > 0
                      ? '${caloriesIntake.toStringAsFixed(0)} kcal'
                      : '—',
                  color: cardTheme?.contentColor ?? theme.colorScheme.primary,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MetricChip extends StatelessWidget {
  const _MetricChip({
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
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 4),
            Text(
              label,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: color.withValues(alpha: 0.9),
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
  }
}
