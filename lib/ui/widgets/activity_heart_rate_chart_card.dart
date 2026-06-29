import 'package:fitai_analyzer/theme/app_theme.dart';
import 'package:fitai_analyzer/utils/activity_hr_series.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

/// Grafico lineare FC (bpm) nel tempo durante l’attività.
///
/// La geometria (downsample + estremi + `FlSpot`) è calcolata una sola volta e
/// ricalcolata solo quando cambia l'identità della lista [points], evitando il
/// lavoro pesante ad ogni rebuild (fl_chart ridisegna spesso).
class ActivityHeartRateChartCard extends StatefulWidget {
  const ActivityHeartRateChartCard({
    super.key,
    required this.points,
    this.sourceLabel,
  });

  final List<ActivityHrPoint> points;
  final String? sourceLabel;

  @override
  State<ActivityHeartRateChartCard> createState() =>
      _ActivityHeartRateChartCardState();
}

class _ActivityHeartRateChartCardState
    extends State<ActivityHeartRateChartCard> {
  HrChartGeometry? _geometry;
  List<FlSpot>? _spots;

  @override
  void initState() {
    super.initState();
    _recompute();
  }

  @override
  void didUpdateWidget(covariant ActivityHeartRateChartCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.points, widget.points)) {
      _recompute();
    }
  }

  void _recompute() {
    if (widget.points.length < 2) {
      _geometry = null;
      _spots = null;
      return;
    }
    final geo = buildHrChartGeometry(widget.points);
    _geometry = geo;
    _spots = geo.points
        .map((p) => FlSpot(p.elapsedSeconds / 60.0, p.bpm))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final geo = _geometry;
    final spots = _spots;
    if (geo == null || spots == null) return const SizedBox.shrink();

    final minX = geo.minX;
    final maxX = geo.maxX;
    final minY = geo.minY;
    final maxY = geo.maxY;

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
            if (widget.sourceLabel != null &&
                widget.sourceLabel!.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(
                widget.sourceLabel!,
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
