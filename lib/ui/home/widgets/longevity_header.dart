import 'package:fitai_analyzer/providers/today_longevity_metrics_provider.dart';
import 'package:fitai_analyzer/theme/app_card_theme.dart';
import 'package:fitai_analyzer/theme/app_theme.dart';
import 'package:fitai_analyzer/ui/widgets/design/design.dart';
import 'package:fitai_analyzer/ui/widgets/nature_icon.dart';
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
    final muted =
        cardTheme?.contentColorMuted ??
        theme.colorScheme.onPrimary.withValues(alpha: 0.9);

    return FitHeroCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              NatureIcon(
                NatureIcons.sun,
                size: 22,
                color: cardTheme?.contentColor ?? theme.colorScheme.onSurface,
                glow: true,
              ),
              const SizedBox(width: 8),
              Text(
                'OGGI',
                style: AppText.sectionTitle(
                  fontSize: 13,
                  color: cardTheme?.contentColor ?? theme.colorScheme.onSurface,
                ),
              ),
              const Spacer(),
              NatureIcon(
                NatureIcons.percorso,
                size: 54,
                color: cardTheme?.contentColor ?? theme.colorScheme.onSurface,
                glow: true,
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Carico di Longevità',
            style: theme.textTheme.bodySmall?.copyWith(color: muted),
          ),
          const SizedBox(height: 20),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: FitMetricDisplay(
                  align: CrossAxisAlignment.center,
                  onHeroSurface: true,
                  valueFontSize: 22,
                  value: m.steps > 0 ? m.steps.toStringAsFixed(0) : '—',
                  caption: 'Passi',
                ),
              ),
              Expanded(
                child: FitMetricDisplay(
                  align: CrossAxisAlignment.center,
                  onHeroSurface: true,
                  valueFontSize: 22,
                  value: m.caloriesBurned > 0
                      ? m.caloriesBurned.toStringAsFixed(0)
                      : '—',
                  unit: m.caloriesBurned > 0 ? 'kcal' : null,
                  caption: 'Bruciate',
                ),
              ),
              Expanded(
                child: FitMetricDisplay(
                  align: CrossAxisAlignment.center,
                  onHeroSurface: true,
                  valueFontSize: 22,
                  value: m.caloriesIntake > 0
                      ? m.caloriesIntake.toStringAsFixed(0)
                      : '—',
                  unit: m.caloriesIntake > 0 ? 'kcal' : null,
                  caption: 'Assunte',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
