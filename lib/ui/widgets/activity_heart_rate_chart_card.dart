import 'dart:math' as math;

import 'package:fitai_analyzer/theme/app_theme.dart';
import 'package:fitai_analyzer/utils/activity_hr_series.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

/// Grafico lineare FC (bpm) nel tempo durante l’attività.
class ActivityHeartRateChartCard extends StatelessWidget {
  const ActivityHeartRateChartCard({
    super.key,
    required this.points,
    this.sourceLabel,
  });

  final List<ActivityHrPoint> points;
  final String? sourceLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (points.length < 2) return const SizedBox.shrink();

    final chartPoints = downsampleHrSeries(points);
    final maxSec = chartPoints
        .map((p) => p.elapsedSeconds)
        .reduce(math.max);
    final minSec = chartPoints
        .map((p) => p.elapsedSeconds)
        .reduce(math.min);
    final maxBpm = chartPoints.map((p) => p.bpm).reduce(math.max);
    final minBpm = chartPoints.map((p) => p.bpm).reduce(math.min);

    final minX = (minSec / 60.0);
    final maxX = math.max(maxSec / 60.0, minX + 1e-3);
    final minY = math.max(35, (minBpm - 8).floorToDouble());
    final maxY = math.max(minY + 10, (maxBpm + 12).ceilToDouble());

    final spots = chartPoints
        .map((p) => FlSpot(p.elapsedSeconds / 60.0, p.bpm))
        .toList();

    final hrColor = AppColors.garminBlue;

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
              'Frequenza cardiaca',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            if (sourceLabel != null && sourceLabel!.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(
                sourceLabel!,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            const SizedBox(height: 12),
            SizedBox(
              height: 200,
              child: LineChart(
                LineChartData(
                  minX: minX,
                  maxX: maxX,
                  minY: minY.toDouble(),
                  maxY: maxY.toDouble(),
                  clipData: const FlClipData.all(),
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: (maxY - minY) > 40 ? 20 : 10,
                    getDrawingHorizontalLine: (v) => FlLine(
                      color: theme.colorScheme.outline.withValues(alpha: 0.15),
                      strokeWidth: 1,
                    ),
                  ),
                  borderData: FlBorderData(
                    show: true,
                    border: Border(
                      bottom: BorderSide(
                        color: theme.colorScheme.outline.withValues(alpha: 0.3),
                      ),
                      left: BorderSide(
                        color: theme.colorScheme.outline.withValues(alpha: 0.3),
                      ),
                    ),
                  ),
                  titlesData: FlTitlesData(
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 36,
                        interval: (maxY - minY) > 40 ? 20 : 10,
                        getTitlesWidget: (v, meta) => Text(
                          v.toInt().toString(),
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                            fontSize: 10,
                          ),
                        ),
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 28,
                        interval: _niceTimeIntervalMinutes(maxX - minX),
                        getTitlesWidget: (v, meta) {
                          final m = v.floor();
                          return Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(
                              '${m}m',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                                fontSize: 10,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  lineTouchData: LineTouchData(
                    enabled: true,
                    touchTooltipData: LineTouchTooltipData(
                      getTooltipItems: (touched) {
                        return touched.map((t) {
                          final minTotal = (t.x * 60).round();
                          final mm = minTotal ~/ 60;
                          final ss = minTotal % 60;
                          return LineTooltipItem(
                            '$mm:${ss.toString().padLeft(2, '0')}\n'
                            '${t.y.toStringAsFixed(0)} bpm',
                            TextStyle(
                              color: theme.colorScheme.onPrimaryContainer,
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                            ),
                          );
                        }).toList();
                      },
                    ),
                  ),
                  lineBarsData: [
                    LineChartBarData(
                      spots: spots,
                      isCurved: true,
                      curveSmoothness: 0.22,
                      color: hrColor,
                      barWidth: 2.2,
                      isStrokeCapRound: true,
                      dotData: const FlDotData(show: false),
                      belowBarData: BarAreaData(
                        show: true,
                        color: hrColor.withValues(alpha: 0.12),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

double _niceTimeIntervalMinutes(double spanMin) {
  if (spanMin <= 0) return 1;
  if (spanMin <= 15) return 2;
  if (spanMin <= 45) return 5;
  if (spanMin <= 120) return 10;
  return 20;
}
