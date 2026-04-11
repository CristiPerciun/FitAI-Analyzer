import 'dart:math' as math;

import 'package:fitai_analyzer/models/fitness_data.dart';
import 'package:fitai_analyzer/theme/app_card_theme.dart';
import 'package:fitai_analyzer/theme/app_theme.dart';
import 'package:fitai_analyzer/ui/widgets/activity_heart_rate_chart_card.dart';
import 'package:fitai_analyzer/utils/activity_hr_series.dart';
import 'package:fitai_analyzer/utils/garmin_activity_chart_parsers.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

/// Grafici da `garmin_raw` (formato Garmin Connect `get_activity` / `get_activity_details` via python-garminconnect sul server).
class GarminActivityChartsSection extends StatelessWidget {
  const GarminActivityChartsSection({
    super.key,
    required this.activity,
  });

  final FitnessData activity;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cardExt = theme.extension<AppCardTheme>();
    // Spesso i numeri utili sono su FitnessData anche se `garmin_raw` è vuoto o minimale.
    final raw = activity.garminRaw ?? {};

    final hr = extractGarminHeartRateSeries(raw);
    final speed = extractGarminSpeedSeriesKmh(raw);
    final elev = extractGarminElevationSeriesM(raw);
    final zones = extractGarminHrZoneSegments(raw);
    final laps = extractGarminLaps(raw);
    final lapsWithHr =
        laps.where((l) => l.avgHeartRate != null && l.avgHeartRate! > 0).toList();

    final hasTimeSeries = hr.length >= 2 ||
        speed.length >= 2 ||
        elev.length >= 2 ||
        zones.length >= 2 ||
        lapsWithHr.length >= 2;

    final avgHr = activity.stravaAvgHeartrate;
    final maxHr = activity.stravaMaxHeartrate;
    final showSummaryHr =
        hr.length < 2 && (avgHr != null || maxHr != null);

    final distKm = activity.distanceKm ?? 0;
    final cal = activity.calories;
    final elevGain = activity.stravaElevationGainM;
    final steps = activity.steps;
    final showSummaryLoad = distKm > 0 ||
        (cal != null && cal > 0) ||
        (elevGain != null && elevGain > 0) ||
        (steps != null && steps > 0);

    final chartCards = <Widget>[];

    if (showSummaryHr) {
      chartCards.add(_GarminSummaryHrBarCard(avg: avgHr, max: maxHr));
      chartCards.add(const SizedBox(height: 12));
    }

    if (showSummaryLoad) {
      chartCards.add(
        _GarminSummaryTrainingLoadCard(
          distanceKm: distKm,
          calories: cal,
          elevationM: elevGain,
          steps: steps,
        ),
      );
      chartCards.add(const SizedBox(height: 12));
    }

    if (hr.length >= 2) {
      chartCards.add(
        ActivityHeartRateChartCard(
          points: hr
              .map((p) => ActivityHrPoint(p.elapsedSeconds, p.value))
              .toList(),
          sourceLabel: 'Serie temporale (garmin_raw)',
        ),
      );
      chartCards.add(const SizedBox(height: 12));
    }

    if (speed.length >= 2) {
      chartCards.add(
        _GarminScalarLineChartCard(
          title: 'Velocità',
          subtitle: 'km/h (da directSpeed / speed)',
          points: speed,
          lineColor: Colors.deepOrange,
          formatYAxis: (y) => y.toStringAsFixed(1),
          formatTooltip: (y) => '${y.toStringAsFixed(1)} km/h',
        ),
      );
      chartCards.add(const SizedBox(height: 12));
    }

    if (elev.length >= 2) {
      chartCards.add(
        _GarminScalarLineChartCard(
          title: 'Altitudine',
          subtitle: 'metri',
          points: elev,
          lineColor: Colors.teal,
          formatYAxis: (y) => y.toStringAsFixed(0),
          formatTooltip: (y) => '${y.toStringAsFixed(0)} m',
        ),
      );
      chartCards.add(const SizedBox(height: 12));
    }

    if (zones.length >= 2) {
      chartCards.add(_GarminHrZonesBarCard(zones: zones));
      chartCards.add(const SizedBox(height: 12));
    }

    if (lapsWithHr.length >= 2) {
      chartCards.add(_GarminLapsHrBarCard(laps: lapsWithHr));
    }

    if (chartCards.isNotEmpty && chartCards.last is SizedBox) {
      chartCards.removeLast();
    }

    final hasAnyVisual =
        showSummaryHr || showSummaryLoad || hasTimeSeries;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 16),
        Text(
          'Grafici',
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
            color: cardExt?.contentColor ?? theme.colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          hasTimeSeries
              ? 'Serie da garmin_raw (dettaglio Connect) e sintesi attività.'
              : 'Sintesi dai campi attività; le curve nel tempo richiedono activityDetailMetrics in garmin_raw.',
          style: theme.textTheme.labelSmall?.copyWith(
            color: cardExt?.contentColorMuted ??
                theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 12),
        if (hasAnyVisual)
          Theme(
            data: theme.copyWith(
              cardTheme: CardThemeData(
                color: theme.colorScheme.surfaceContainerHigh,
                elevation: 1,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(
                    color: theme.colorScheme.outline.withValues(alpha: 0.2),
                  ),
                ),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: chartCards,
            ),
          ),
        if (!hasAnyVisual)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              'Nessun dato numerico per un grafico (manca distanza, FC, calorie, ecc.).',
              style: theme.textTheme.bodySmall?.copyWith(
                color: cardExt?.contentColorMuted ??
                    theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        if (!hasTimeSeries && hasAnyVisual)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Text(
              'Per grafici come nell’app Garmin (FC/velocità nel tempo) serve il dettaglio completo sul server: garmin_raw con activityDetailMetrics (API …/activity/{id}/details).',
              style: theme.textTheme.labelSmall?.copyWith(
                color: cardExt?.contentColorMuted ??
                    theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
      ],
    );
  }
}

/// Barre FC media / max dai campi riepilogo (senza serie temporale).
class _GarminSummaryHrBarCard extends StatelessWidget {
  const _GarminSummaryHrBarCard({
    required this.avg,
    required this.max,
  });

  final double? avg;
  final double? max;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final entries = <({String label, double bpm})>[];
    if (avg != null && avg! > 0) {
      entries.add((label: 'Media', bpm: avg!));
    }
    if (max != null && max! > 0) {
      entries.add((label: 'Max', bpm: max!));
    }
    if (entries.isEmpty) return const SizedBox.shrink();

    final maxY = entries.map((e) => e.bpm).reduce(math.max) * 1.12;

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Frequenza cardiaca (riepilogo)',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              'Da campi attività salvati su Firestore',
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 160,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: maxY,
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    getDrawingHorizontalLine: (v) => FlLine(
                      color: theme.colorScheme.outline.withValues(alpha: 0.12),
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
                        getTitlesWidget: (v, meta) => Text(
                          v.toInt().toString(),
                          style: theme.textTheme.labelSmall?.copyWith(
                            fontSize: 10,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 28,
                        getTitlesWidget: (v, meta) {
                          final i = v.toInt();
                          if (i < 0 || i >= entries.length) {
                            return const SizedBox.shrink();
                          }
                          return Text(
                            entries[i].label,
                            style: theme.textTheme.labelSmall?.copyWith(
                              fontSize: 10,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  barTouchData: BarTouchData(
                    enabled: true,
                    touchTooltipData: BarTouchTooltipData(
                      getTooltipItem: (group, groupIndex, rod, rodIndex) {
                        if (groupIndex < 0 || groupIndex >= entries.length) {
                          return null;
                        }
                        final e = entries[groupIndex];
                        return BarTooltipItem(
                          '${e.label}: ${e.bpm.toStringAsFixed(0)} bpm',
                          TextStyle(
                            color: theme.colorScheme.onPrimaryContainer,
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        );
                      },
                    ),
                  ),
                  barGroups: List.generate(entries.length, (i) {
                    final e = entries[i];
                    return BarChartGroupData(
                      x: i,
                      barRods: [
                        BarChartRodData(
                          toY: e.bpm,
                          width: 28,
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(8),
                          ),
                          color: AppColors.garminBlue,
                        ),
                      ],
                    );
                  }),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Barre proporzionali (carico relativo) per distanza, calorie, dislivello, passi.
class _GarminSummaryTrainingLoadCard extends StatelessWidget {
  const _GarminSummaryTrainingLoadCard({
    required this.distanceKm,
    required this.calories,
    required this.elevationM,
    required this.steps,
  });

  final double distanceKm;
  final double? calories;
  final double? elevationM;
  final double? steps;

  static double _clamp01(double x) => x.clamp(0.0, 1.0);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final rows = <Widget>[];

    if (distanceKm > 0) {
      rows.add(
        _loadRow(
          theme,
          Icons.straighten,
          'Distanza',
          '${distanceKm.toStringAsFixed(2)} km',
          _clamp01(distanceKm / 50.0),
          Colors.deepOrange,
        ),
      );
    }
    if (calories != null && calories! > 0) {
      rows.add(
        _loadRow(
          theme,
          Icons.local_fire_department,
          'Calorie',
          '${calories!.toInt()} kcal',
          _clamp01(calories! / 2500.0),
          Colors.orange,
        ),
      );
    }
    if (elevationM != null && elevationM! > 0) {
      rows.add(
        _loadRow(
          theme,
          Icons.terrain,
          'Dislivello',
          '${elevationM!.toInt()} m',
          _clamp01(elevationM! / 1500.0),
          Colors.teal,
        ),
      );
    }
    if (steps != null && steps! > 0) {
      rows.add(
        _loadRow(
          theme,
          Icons.directions_walk,
          'Passi',
          steps!.toInt().toString(),
          _clamp01(steps! / 25000.0),
          Colors.blueGrey,
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Volume (scala relativa)',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              'Confronto visivo tra metriche (non stessa unità)',
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            ...rows,
          ],
        ),
      ),
    );
  }

  Widget _loadRow(
    ThemeData theme,
    IconData icon,
    String label,
    String value,
    double ratio,
    Color color,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Text(
                value,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: ratio,
              minHeight: 10,
              backgroundColor:
                  theme.colorScheme.outline.withValues(alpha: 0.12),
              color: color.withValues(alpha: 0.85),
            ),
          ),
        ],
      ),
    );
  }
}

class _GarminScalarLineChartCard extends StatelessWidget {
  const _GarminScalarLineChartCard({
    required this.title,
    required this.subtitle,
    required this.points,
    required this.lineColor,
    required this.formatYAxis,
    required this.formatTooltip,
  });

  final String title;
  final String subtitle;
  final List<GarminChartPoint> points;
  final Color lineColor;
  final String Function(double y) formatYAxis;
  final String Function(double y) formatTooltip;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final chartPoints = downsampleGarminChartPoints(points);
    final maxSec = chartPoints.map((p) => p.elapsedSeconds).reduce(math.max);
    final minSec = chartPoints.map((p) => p.elapsedSeconds).reduce(math.min);
    final maxYv = chartPoints.map((p) => p.value).reduce(math.max);
    final minYv = chartPoints.map((p) => p.value).reduce(math.min);
    final pad = (maxYv - minYv).abs() < 1e-6 ? 1.0 : (maxYv - minYv) * 0.1;

    final minX = minSec / 60.0;
    final maxX = math.max(maxSec / 60.0, minX + 1e-3);
    final minY = minYv - pad;
    final maxY = maxYv + pad;

    final spots = chartPoints
        .map((p) => FlSpot(p.elapsedSeconds / 60.0, p.value))
        .toList();

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
              title,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              subtitle,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 180,
              child: LineChart(
                LineChartData(
                  minX: minX,
                  maxX: maxX,
                  minY: minY,
                  maxY: maxY,
                  clipData: const FlClipData.all(),
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
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
                        reservedSize: 40,
                        getTitlesWidget: (v, meta) => Text(
                          formatYAxis(v),
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                            fontSize: 9,
                          ),
                        ),
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 28,
                        interval: _niceTimeIntervalMinutes(maxX - minX),
                        getTitlesWidget: (v, meta) => Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            '${v.floor()}m',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                              fontSize: 10,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  lineTouchData: LineTouchData(
                    enabled: true,
                    touchTooltipData: LineTouchTooltipData(
                      getTooltipItems: (touched) {
                        return touched.map((t) {
                          final sec = (t.x * 60).round();
                          final mm = sec ~/ 60;
                          final ss = sec % 60;
                          return LineTooltipItem(
                            '$mm:${ss.toString().padLeft(2, '0')}\n'
                            '${formatTooltip(t.y)}',
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
                      curveSmoothness: 0.2,
                      color: lineColor,
                      barWidth: 2,
                      isStrokeCapRound: true,
                      dotData: const FlDotData(show: false),
                      belowBarData: BarAreaData(
                        show: true,
                        color: lineColor.withValues(alpha: 0.1),
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

class _GarminHrZonesBarCard extends StatelessWidget {
  const _GarminHrZonesBarCard({required this.zones});

  final List<GarminHrZoneSegment> zones;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final maxSec = zones.map((z) => z.seconds).reduce(math.max);
    final maxY = maxSec <= 0 ? 1.0 : maxSec * 1.08;
    final colors = [
      Colors.blue.shade300,
      Colors.green.shade400,
      Colors.amber.shade600,
      Colors.orange.shade700,
      Colors.red.shade600,
    ];

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
              'Tempo in zona FC',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 180,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: maxY,
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    getDrawingHorizontalLine: (v) => FlLine(
                      color: theme.colorScheme.outline.withValues(alpha: 0.12),
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
                        getTitlesWidget: (v, meta) => Text(
                          '${(v / 60).floor()}m',
                          style: theme.textTheme.labelSmall?.copyWith(
                            fontSize: 9,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 24,
                        getTitlesWidget: (v, meta) {
                          final i = v.toInt() - 1;
                          if (i < 0 || i >= zones.length) {
                            return const SizedBox.shrink();
                          }
                          return Text(
                            'Z${zones[i].zoneIndex}',
                            style: theme.textTheme.labelSmall?.copyWith(
                              fontSize: 10,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  barTouchData: BarTouchData(
                    enabled: true,
                    touchTooltipData: BarTouchTooltipData(
                      getTooltipItem: (group, groupIndex, rod, rodIndex) {
                        if (groupIndex < 0 || groupIndex >= zones.length) {
                          return null;
                        }
                        final z = zones[groupIndex];
                        final min = (z.seconds / 60).floor();
                        final s = z.seconds.round() % 60;
                        return BarTooltipItem(
                          'Zona ${z.zoneIndex}\n$min min $s s',
                          TextStyle(
                            color: theme.colorScheme.onPrimaryContainer,
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        );
                      },
                    ),
                  ),
                  barGroups: List.generate(zones.length, (i) {
                    final z = zones[i];
                    final c = colors[(z.zoneIndex - 1).clamp(0, colors.length - 1)];
                    return BarChartGroupData(
                      x: i + 1,
                      barRods: [
                        BarChartRodData(
                          toY: z.seconds,
                          width: 18,
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(6),
                          ),
                          color: c,
                        ),
                      ],
                    );
                  }),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GarminLapsHrBarCard extends StatelessWidget {
  const _GarminLapsHrBarCard({required this.laps});

  final List<GarminLapSummary> laps;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hrs = laps.map((l) => l.avgHeartRate!).toList();
    final maxHr = hrs.reduce(math.max);
    final minHr = hrs.reduce(math.min);
    final maxY = maxHr * 1.06;
    final minY = math.max(30.0, minHr * 0.88);

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
              'FC media per giro',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 180,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  minY: minY,
                  maxY: maxY,
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    getDrawingHorizontalLine: (v) => FlLine(
                      color: theme.colorScheme.outline.withValues(alpha: 0.12),
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
                        reservedSize: 32,
                        getTitlesWidget: (v, meta) => Text(
                          v.toInt().toString(),
                          style: theme.textTheme.labelSmall?.copyWith(
                            fontSize: 9,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 22,
                        getTitlesWidget: (v, meta) {
                          final i = v.toInt();
                          if (i < 0 || i >= laps.length) {
                            return const SizedBox.shrink();
                          }
                          return Text(
                            '${laps[i].lapIndex}',
                            style: theme.textTheme.labelSmall?.copyWith(
                              fontSize: 10,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  barTouchData: BarTouchData(
                    enabled: true,
                    touchTooltipData: BarTouchTooltipData(
                      getTooltipItem: (group, groupIndex, rod, rodIndex) {
                        if (groupIndex < 0 || groupIndex >= laps.length) {
                          return null;
                        }
                        final l = laps[groupIndex];
                        return BarTooltipItem(
                          'Giro ${l.lapIndex}\n'
                          '${l.avgHeartRate!.toStringAsFixed(0)} bpm',
                          TextStyle(
                            color: theme.colorScheme.onPrimaryContainer,
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        );
                      },
                    ),
                  ),
                  barGroups: List.generate(laps.length, (i) {
                    final l = laps[i];
                    return BarChartGroupData(
                      x: i,
                      barRods: [
                        BarChartRodData(
                          toY: l.avgHeartRate!,
                          width: 14,
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(6),
                          ),
                          color: AppColors.garminBlue,
                        ),
                      ],
                    );
                  }),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
