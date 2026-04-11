import 'package:fitai_analyzer/providers/nutrition_chart_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Card con barre impilate P / C / G per ogni giorno (stessi colori macro usati in [NutritionChartCard]).
class WeeklyMacroStackedBarChartCard extends ConsumerWidget {
  const WeeklyMacroStackedBarChartCard({super.key});

  /// Allineato a [NutritionDiaryWeekOffsetNotifier.setWeeksAgo] (max 12).
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

    return chartAsync.when(
      data: (data) {
        final totalKcal = data.caloriesData.fold<double>(0, (a, e) => a + e.value);
        final dailyAvgKcal = totalKcal / 7.0;
        final macroColors = _macroColors(theme);

        return Card(
          elevation: 0,
          color: cs.surfaceContainerHighest.withValues(alpha: 0.55),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  height: 44,
                  child: Row(
                    children: [
                      SizedBox(
                        width: 44,
                        height: 44,
                        child: weekOffset < _maxWeeksBack
                            ? IconButton(
                                padding: EdgeInsets.zero,
                                tooltip: 'Settimana precedente',
                                icon: Icon(Icons.chevron_left, color: cs.primary),
                                onPressed: () => ref
                                    .read(nutritionDiaryWeekOffsetProvider.notifier)
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
                            ? IconButton(
                                padding: EdgeInsets.zero,
                                tooltip: 'Settimana successiva',
                                icon: Icon(Icons.chevron_right, color: cs.primary),
                                onPressed: () => ref
                                    .read(nutritionDiaryWeekOffsetProvider.notifier)
                                    .setWeeksAgo(weekOffset - 1),
                              )
                            : const SizedBox.shrink(),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
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
                SizedBox(
                  height: 220,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: List.generate(7, (dayIndex) {
                      return Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 3),
                          child: _DayMacroColumn(
                            dayLabel: data.caloriesData[dayIndex].day,
                            kcal: data.caloriesData[dayIndex].value,
                            proteinG: data.proteinData[dayIndex].value,
                            carbsG: data.carbsData[dayIndex].value,
                            fatG: data.fatData[dayIndex].value,
                            proteinColor: macroColors.protein,
                            carbsColor: macroColors.carbs,
                            fatColor: macroColors.fat,
                            theme: theme,
                          ),
                        ),
                      );
                    }),
                  ),
                ),
                const SizedBox(height: 12),
                _LegendRow(theme: theme, macroColors: macroColors),
              ],
            ),
          ),
        );
      },
      loading: () => Card(
        elevation: 0,
        color: cs.surfaceContainerHighest.withValues(alpha: 0.55),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: const SizedBox(
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

_MacroColors _macroColors(ThemeData theme) {
  final dark = theme.brightness == Brightness.dark;
  // Stessi accenti della pagina Alimentazione (NutritionChartCard / NutrientGoal), versione pastello.
  if (dark) {
    return _MacroColors(
      protein: Color.lerp(Colors.purpleAccent, Colors.black, 0.35)!,
      carbs: Color.lerp(Colors.greenAccent, Colors.black, 0.35)!,
      fat: Color.lerp(Colors.orangeAccent, Colors.black, 0.35)!,
    );
  }
  return _MacroColors(
    protein: Color.lerp(Colors.purpleAccent, Colors.white, 0.72)!,
    carbs: Color.lerp(Colors.greenAccent, Colors.white, 0.75)!,
    fat: Color.lerp(Colors.orangeAccent, Colors.white, 0.72)!,
  );
}

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
      crossAxisAlignment: alignEnd ? CrossAxisAlignment.end : CrossAxisAlignment.start,
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

class _DayMacroColumn extends StatelessWidget {
  const _DayMacroColumn({
    required this.dayLabel,
    required this.kcal,
    required this.proteinG,
    required this.carbsG,
    required this.fatG,
    required this.proteinColor,
    required this.carbsColor,
    required this.fatColor,
    required this.theme,
  });

  final String dayLabel;
  final double kcal;
  final double proteinG;
  final double carbsG;
  final double fatG;
  final Color proteinColor;
  final Color carbsColor;
  final Color fatColor;
  final ThemeData theme;

  static const double _maxStackPx = 148;
  static const double _segmentGap = 5;
  static const double _minLabeledSegment = 22;

  @override
  Widget build(BuildContext context) {
    final cs = theme.colorScheme;
    final totalG = proteinG + carbsG + fatG;
    final hasData = totalG > 0;

    double hFor(double grams) {
      if (!hasData || grams <= 0) return 0;
      final raw = (grams / totalG) * _maxStackPx;
      return raw.clamp(grams > 0 ? 18.0 : 0.0, _maxStackPx);
    }

    var hp = hFor(proteinG);
    var hc = hFor(carbsG);
    var hf = hFor(fatG);
    final sum = hp + hc + hf;
    final gaps = (proteinG > 0 ? 1 : 0) + (carbsG > 0 ? 1 : 0) + (fatG > 0 ? 1 : 0) - 1;
    final gapTotal = gaps > 0 ? (gaps * _segmentGap) : 0.0;
    if (sum + gapTotal > _maxStackPx && sum > 0) {
      final scale = (_maxStackPx - gapTotal) / sum;
      hp *= scale;
      hc *= scale;
      hf *= scale;
    }

    Widget segment(double h, double grams, String suffix, Color bg) {
      if (grams <= 0 || h <= 0) return const SizedBox.shrink();
      final showLabel = h >= _minLabeledSegment;
      return Container(
        height: h,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(10),
        ),
        alignment: Alignment.center,
        child: showLabel
            ? Text(
                '${grams.round()} $suffix',
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.fade,
                softWrap: false,
                style: theme.textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: cs.onSurface.withValues(alpha: 0.92),
                  fontSize: 9,
                ),
              )
            : null,
      );
    }

    final badgeBg = cs.inverseSurface;
    final badgeFg = cs.onInverseSurface;

    return Column(
      children: [
        SizedBox(
          height: 28,
          child: Center(
            child: kcal > 0
                ? Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: badgeBg,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      kcal.round().toString(),
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: badgeFg,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  )
                : null,
          ),
        ),
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (proteinG > 0) ...[
                segment(hp, proteinG, 'P', proteinColor),
                if (carbsG > 0 || fatG > 0) const SizedBox(height: _segmentGap),
              ],
              if (carbsG > 0) ...[
                segment(hc, carbsG, 'C', carbsColor),
                if (fatG > 0) const SizedBox(height: _segmentGap),
              ],
              if (fatG > 0) segment(hf, fatG, 'G', fatColor),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Text(
          dayLabel,
          textAlign: TextAlign.center,
          style: theme.textTheme.labelSmall?.copyWith(
            color: cs.onSurfaceVariant,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _LegendRow extends StatelessWidget {
  const _LegendRow({required this.theme, required this.macroColors});

  final ThemeData theme;
  final _MacroColors macroColors;

  @override
  Widget build(BuildContext context) {
    final cs = theme.colorScheme;
    return Wrap(
      spacing: 12,
      runSpacing: 8,
      children: [
        _LegendItem(color: cs.inverseSurface, label: 'Calorie', theme: theme),
        _LegendItem(color: macroColors.protein, label: 'Proteine', theme: theme),
        _LegendItem(color: macroColors.carbs, label: 'Carboidrati', theme: theme),
        _LegendItem(color: macroColors.fat, label: 'Grassi', theme: theme),
      ],
    );
  }
}

class _LegendItem extends StatelessWidget {
  const _LegendItem({
    required this.color,
    required this.label,
    required this.theme,
  });

  final Color color;
  final String label;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
