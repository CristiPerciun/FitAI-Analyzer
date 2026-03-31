import 'package:fitai_analyzer/providers/today_longevity_metrics_provider.dart';
import 'package:fitai_analyzer/theme/app_card_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Header dinamico che mostra il "Carico di Longevità" odierno.
/// Passi da `daily_health` e calorie attività da `activities`.
class LongevityHeader extends ConsumerWidget {
  const LongevityHeader({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final m = ref.watch(todayLongevityMetricsProvider);

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
                Expanded(
                  child: _MetricChip(
                    icon: Icons.directions_walk,
                    label: 'Passi',
                    value: m.steps > 0 ? m.steps.toStringAsFixed(0) : '—',
                    color: cardTheme?.contentColor ?? theme.colorScheme.primary,
                  ),
                ),
                Expanded(
                  child: _MetricChip(
                    icon: Icons.local_fire_department,
                    label: 'Bruciate',
                    value: m.caloriesBurned > 0
                        ? '${m.caloriesBurned.toStringAsFixed(0)} kcal'
                        : '—',
                    color: cardTheme?.contentColor ?? theme.colorScheme.primary,
                  ),
                ),
                Expanded(
                  child: _MetricChip(
                    icon: Icons.restaurant,
                    label: 'Assunte',
                    value: m.caloriesIntake > 0
                        ? '${m.caloriesIntake.toStringAsFixed(0)} kcal'
                        : '—',
                    color: cardTheme?.contentColor ?? theme.colorScheme.primary,
                  ),
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
      crossAxisAlignment: CrossAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
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
