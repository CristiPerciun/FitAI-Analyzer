import 'package:fitai_analyzer/providers/dashboard_activity_providers.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ActivityBurnBarChartCard extends ConsumerWidget {
  const ActivityBurnBarChartCard({super.key});

  static double _maxY(List<ActivityBurnBarPoint> points) {
    final m = points.map((p) => p.kcal).fold<double>(0, (a, b) => a > b ? a : b);
    return m <= 0 ? 200 : (m * 1.15).clamp(50, double.infinity);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final mode = ref.watch(activityBurnChartModeProvider);
    final points = ref.watch(activityBurnChartPointsProvider);
    final maxY = _maxY(points);

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: theme.colorScheme.outline.withValues(alpha: 0.2),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Calorie bruciate (attività)',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Dati da Strava / Garmin (Firestore)',
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: SegmentedButton<ActivityBurnChartMode>(
                segments: const [
                  ButtonSegment(
                    value: ActivityBurnChartMode.week,
                    label: Text('Settimana'),
                    icon: Icon(Icons.date_range, size: 16),
                  ),
                  ButtonSegment(
                    value: ActivityBurnChartMode.month,
                    label: Text('Mese'),
                    icon: Icon(Icons.calendar_view_month, size: 16),
                  ),
                ],
                selected: {mode},
                onSelectionChanged: (s) {
                  ref.read(activityBurnChartModeProvider.notifier).state =
                      s.first;
                },
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: maxY,
                  barTouchData: BarTouchData(
                    enabled: true,
                    touchTooltipData: BarTouchTooltipData(
                      getTooltipColor: (_) =>
                          theme.colorScheme.inverseSurface.withValues(alpha: 0.9),
                      getTooltipItem: (group, groupIndex, rod, rodIndex) {
                        final i = group.x.toInt();
                        if (i < 0 || i >= points.length) return null;
                        final p = points[i];
                        return BarTooltipItem(
                          '${p.label}\n${p.kcal.toStringAsFixed(0)} kcal',
                          TextStyle(
                            color: theme.colorScheme.onInverseSurface,
                            fontSize: 12,
                          ),
                        );
                      },
                    ),
                  ),
                  titlesData: FlTitlesData(
                    show: true,
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: mode == ActivityBurnChartMode.month ? 18 : 26,
                        interval: 1,
                        getTitlesWidget: (value, meta) {
                          final i = value.toInt();
                          if (i < 0 || i >= points.length) {
                            return const SizedBox.shrink();
                          }
                          if (mode == ActivityBurnChartMode.month) {
                            final day = i + 1;
                            if (day != 1 &&
                                day != 5 &&
                                day != 10 &&
                                day != 15 &&
                                day != 20 &&
                                day != 25 &&
                                day != points.length) {
                              return const SizedBox.shrink();
                            }
                          }
                          return Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(
                              points[i].label,
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                                fontSize: mode == ActivityBurnChartMode.month ? 8 : 10,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 34,
                        interval: maxY / 4,
                        getTitlesWidget: (value, meta) => Text(
                          value.toInt().toString(),
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                            fontSize: 9,
                          ),
                        ),
                      ),
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
                    horizontalInterval: maxY / 4,
                    getDrawingHorizontalLine: (value) => FlLine(
                      color: theme.colorScheme.outline.withValues(alpha: 0.2),
                      strokeWidth: 1,
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  barGroups: points.asMap().entries.map((e) {
                    return BarChartGroupData(
                      x: e.key,
                      barRods: [
                        BarChartRodData(
                          toY: e.value.kcal,
                          color: theme.colorScheme.primary.withValues(alpha: 0.85),
                          width: mode == ActivityBurnChartMode.month ? 4 : 10,
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(4),
                          ),
                        ),
                      ],
                    );
                  }).toList(),
                ),
                duration: const Duration(milliseconds: 250),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
