import 'package:fitai_analyzer/providers/nutrition_chart_provider.dart';
import 'package:fitai_analyzer/ui/widgets/design/design.dart';
import 'package:fitai_analyzer/utils/nutrition_macro_colors.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Card settimanale macros — stacked BarChart (fl_chart) con animazione.
/// Segmenti per barra (dal basso): Grassi → Carboidrati → Proteine.
class WeeklyMacroStackedBarChartCard extends ConsumerWidget {
  const WeeklyMacroStackedBarChartCard({super.key});

  static const int _maxWeeksBack = 12;

  static String _weekTitle(int weekOffset) {
    if (weekOffset == 0) return 'Questa settimana';
    if (weekOffset == 1) return 'Settimana scorsa';
    return '$weekOffset settimane fa';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chartAsync = ref.watch(nutritionDiaryWeekChartDataProvider);
    final weekOffset = ref.watch(nutritionDiaryWeekOffsetProvider);
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final trackColor = cs.onSurface.withValues(alpha: isDark ? 0.06 : 0.05);

    Widget shell(Widget child) =>
        FitSoftCard(padding: EdgeInsets.zero, child: child);

    return chartAsync.when(
      skipLoadingOnReload: true,
      data: (data) {
        final totalKcal = data.caloriesData.fold<double>(
          0,
          (a, e) => a + e.value,
        );
        final dailyAvgKcal = totalKcal / 7.0;
        const mc = _MacroColors(
          protein: NutritionMacroColors.protein,
          carbs: NutritionMacroColors.carbs,
          fat: NutritionMacroColors.fat,
        );

        // Max grams across the 7 days (used for Y axis scale)
        double maxGrams = 10.0;
        for (int i = 0; i < 7; i++) {
          final t =
              data.proteinData[i].value +
              data.carbsData[i].value +
              data.fatData[i].value;
          if (t > maxGrams) maxGrams = t;
        }
        final chartMax = maxGrams * 1.22;
        final gridInterval = (chartMax / 4).ceilToDouble();

        // Totali settimanali per la barra di distribuzione macro.
        double totProtein = 0, totCarbs = 0, totFat = 0;
        for (int i = 0; i < 7; i++) {
          totProtein += data.proteinData[i].value;
          totCarbs += data.carbsData[i].value;
          totFat += data.fatData[i].value;
        }

        // Build stacked bar groups: fat (bottom) → carbs → protein (top)
        final groups = List.generate(7, (i) {
          final p = data.proteinData[i].value;
          final c = data.carbsData[i].value;
          final f = data.fatData[i].value;
          final total = p + c + f;
          return BarChartGroupData(
            x: i,
            barRods: [
              BarChartRodData(
                toY: total <= 0 ? 0.0 : total,
                width: 15,
                color: Colors.transparent,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(8),
                  bottom: Radius.circular(4),
                ),
                backDrawRodData: BackgroundBarChartRodData(
                  show: true,
                  toY: chartMax,
                  color: trackColor,
                ),
                rodStackItems: total <= 0
                    ? []
                    : [
                        BarChartRodStackItem(0, f, mc.fat),
                        BarChartRodStackItem(f, f + c, mc.carbs),
                        BarChartRodStackItem(f + c, total, mc.protein),
                      ],
              ),
            ],
          );
        });

        return shell(
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Week navigation ──────────────────────────────────────
                SizedBox(
                  height: 44,
                  child: Row(
                    children: [
                      SizedBox(
                        width: 44,
                        height: 44,
                        child: weekOffset < _maxWeeksBack
                            ? FitCircleIconButton(
                                icon: Icons.chevron_left,
                                tooltip: 'Settimana precedente',
                                iconColor: cs.primary,
                                onPressed: () => ref
                                    .read(
                                      nutritionDiaryWeekOffsetProvider.notifier,
                                    )
                                    .setWeeksAgo(weekOffset + 1),
                              )
                            : const SizedBox.shrink(),
                      ),
                      Expanded(
                        child: Text(
                          _weekTitle(weekOffset),
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: cs.onSurface,
                          ),
                        ),
                      ),
                      SizedBox(
                        width: 44,
                        height: 44,
                        child: weekOffset > 0
                            ? FitCircleIconButton(
                                icon: Icons.chevron_right,
                                tooltip: 'Settimana successiva',
                                iconColor: cs.primary,
                                onPressed: () => ref
                                    .read(
                                      nutritionDiaryWeekOffsetProvider.notifier,
                                    )
                                    .setWeeksAgo(weekOffset - 1),
                              )
                            : const SizedBox.shrink(),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // ── Summary stats ─────────────────────────────────────────
                Row(
                  children: [
                    Expanded(
                      child: _StatBlock(
                        value: totalKcal.round().toString(),
                        caption: 'Calorie totali',
                        theme: theme,
                      ),
                    ),
                    Expanded(
                      child: _StatBlock(
                        value: dailyAvgKcal.round().toString(),
                        caption: 'Media giornaliera',
                        theme: theme,
                        alignEnd: true,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // ── Distribuzione macro settimanale (barra segmentata) ─────
                if (totProtein + totCarbs + totFat > 0) ...[
                  Text(
                    'Distribuzione macro',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: cs.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 10),
                  FitSegmentedProgressBar(
                    height: 16,
                    colors: [mc.protein, mc.carbs, mc.fat],
                    segments: [
                      FitBarSegment(totProtein, 'Proteine'),
                      FitBarSegment(totCarbs, 'Carboidrati'),
                      FitBarSegment(totFat, 'Grassi'),
                    ],
                  ),
                  const SizedBox(height: 20),
                ],

                // ── Grafico giornaliero (barre slim) ──────────────────────
                SizedBox(
                  height: 210,
                  child: BarChart(
                    BarChartData(
                      alignment: BarChartAlignment.spaceAround,
                      maxY: chartMax,
                      barTouchData: BarTouchData(
                        touchTooltipData: BarTouchTooltipData(
                          getTooltipColor: (_) =>
                              cs.inverseSurface.withValues(alpha: 0.92),
                          tooltipPadding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 8,
                          ),
                          getTooltipItem: (group, _, rod, _) {
                            final i = group.x;
                            final p = data.proteinData[i].value;
                            final c = data.carbsData[i].value;
                            final f = data.fatData[i].value;
                            return BarTooltipItem(
                              'P ${p.round()}g · C ${c.round()}g · G ${f.round()}g',
                              TextStyle(
                                color: cs.onInverseSurface,
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                height: 1.4,
                              ),
                            );
                          },
                        ),
                      ),
                      titlesData: FlTitlesData(
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 28,
                            interval: 1,
                            getTitlesWidget: (value, _) {
                              final i = value.toInt();
                              if (i < 0 || i >= 7) {
                                return const SizedBox.shrink();
                              }
                              return Padding(
                                padding: const EdgeInsets.only(top: 6),
                                child: Text(
                                  data.caloriesData[i].day,
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: cs.onSurfaceVariant,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        leftTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        topTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        rightTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                      ),
                      gridData: FlGridData(
                        show: true,
                        drawVerticalLine: false,
                        horizontalInterval: gridInterval,
                        getDrawingHorizontalLine: (_) => FlLine(
                          color: cs.outline.withValues(alpha: 0.12),
                          strokeWidth: 1,
                        ),
                      ),
                      borderData: FlBorderData(show: false),
                      barGroups: groups,
                    ),
                    duration: const Duration(milliseconds: 550),
                    curve: Curves.easeOutCubic,
                  ),
                ),
              ],
            ),
          ),
        );
      },
      loading: () => shell(
        const SizedBox(
          height: 200,
          child: Center(child: CircularProgressIndicator()),
        ),
      ),
      error: (e, _) => Card(
        elevation: 0,
        color: cs.errorContainer.withValues(alpha: 0.35),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text('Errore grafico: $e', style: theme.textTheme.bodySmall),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Macro colour palette — consistent with NutritionChartCard / alimentazione_screen
// ─────────────────────────────────────────────────────────────────────────────

class _MacroColors {
  const _MacroColors({
    required this.protein,
    required this.carbs,
    required this.fat,
  });

  final Color protein;
  final Color carbs;
  final Color fat;
}

// ─────────────────────────────────────────────────────────────────────────────
// Supporting widgets
// ─────────────────────────────────────────────────────────────────────────────

class _StatBlock extends StatelessWidget {
  const _StatBlock({
    required this.value,
    required this.caption,
    required this.theme,
    this.alignEnd = false,
  });

  final String value;
  final String caption;
  final ThemeData theme;
  final bool alignEnd;

  @override
  Widget build(BuildContext context) {
    final cs = theme.colorScheme;
    return Column(
      crossAxisAlignment: alignEnd
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: cs.onSurface,
          ),
        ),
        Text(
          caption,
          style: theme.textTheme.labelMedium?.copyWith(
            color: cs.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
