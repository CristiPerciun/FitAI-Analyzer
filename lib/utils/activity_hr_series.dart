import 'dart:math' as math;

import 'package:fitai_analyzer/utils/garmin_activity_chart_parsers.dart';

/// Punto (tempo dall’inizio attività, battiti) per grafici FC.
class ActivityHrPoint {
  const ActivityHrPoint(this.elapsedSeconds, this.bpm);

  /// Secondi dall’inizio attività (come stream Strava `time`).
  final double elapsedSeconds;
  final double bpm;
}

/// Geometria pre-calcolata del grafico FC: punti ridotti + estremi assi.
/// Calcolata una sola volta (vedi [buildHrChartGeometry]) per evitare di
/// rifare downsample + min/max ad ogni `build` del grafico.
class HrChartGeometry {
  const HrChartGeometry({
    required this.points,
    required this.minX,
    required this.maxX,
    required this.minY,
    required this.maxY,
  });

  final List<ActivityHrPoint> points;
  final double minX;
  final double maxX;
  final double minY;
  final double maxY;
}

/// Costruisce la [HrChartGeometry] (downsample + estremi) da una serie FC.
HrChartGeometry buildHrChartGeometry(List<ActivityHrPoint> data) {
  final chartPoints = downsampleHrSeries(data);
  final maxSec = chartPoints.map((p) => p.elapsedSeconds).reduce(math.max);
  final minSec = chartPoints.map((p) => p.elapsedSeconds).reduce(math.min);
  final maxBpm = chartPoints.map((p) => p.bpm).reduce(math.max);
  final minBpm = chartPoints.map((p) => p.bpm).reduce(math.min);

  final minX = minSec / 60.0;
  final maxX = math.max(maxSec / 60.0, minX + 1e-3);
  final minY = math.max(35.0, (minBpm - 8).floorToDouble());
  final maxY = math.max(minY + 10, (maxBpm + 12).ceilToDouble());

  return HrChartGeometry(
    points: chartPoints,
    minX: minX,
    maxX: maxX,
    minY: minY,
    maxY: maxY,
  );
}

/// Riduce i punti per il rendering (fl_chart resta leggero).
List<ActivityHrPoint> downsampleHrSeries(
  List<ActivityHrPoint> data, {
  int maxPoints = 360,
}) {
  if (data.length <= maxPoints) return data;
  final step = data.length / maxPoints;
  final out = <ActivityHrPoint>[];
  for (var i = 0; i < maxPoints; i++) {
    final idx = math.min(
      (i * step).floor(),
      data.length - 1,
    );
    out.add(data[idx]);
  }
  return out;
}

/// Estrae una serie FC da `garmin_raw` (include `activityDetailMetrics` da Garmin `.../activity/{id}/details`).
List<ActivityHrPoint> extractActivityHrSeriesFromGarminRaw(
  Map<String, dynamic>? raw,
) {
  return extractGarminHeartRateSeries(raw)
      .map((p) => ActivityHrPoint(p.elapsedSeconds, p.value))
      .toList();
}

/// Costruisce punti da risposta API Strava streams (`key_by_type` o array).
List<ActivityHrPoint>? parseStravaHeartRateStreams(dynamic decoded) {
  List<dynamic>? hrData;
  List<dynamic>? timeData;

  if (decoded is Map<String, dynamic>) {
    final hr = decoded['heartrate'];
    final t = decoded['time'];
    if (hr is Map && hr['data'] is List) {
      hrData = hr['data'] as List<dynamic>;
    }
    if (t is Map && t['data'] is List) {
      timeData = t['data'] as List<dynamic>;
    }
  } else if (decoded is List<dynamic>) {
    for (final e in decoded) {
      if (e is! Map) continue;
      final m = Map<String, dynamic>.from(e);
      final type = m['type']?.toString();
      if (type == 'heartrate' && m['data'] is List) {
        hrData = m['data'] as List<dynamic>;
      }
      if (type == 'time' && m['data'] is List) {
        timeData = m['data'] as List<dynamic>;
      }
    }
  }

  if (hrData == null || hrData.isEmpty) return null;

  final n = hrData.length;
  final out = <ActivityHrPoint>[];
  for (var i = 0; i < n; i++) {
    final hr = hrData[i];
    if (hr is! num || hr <= 0) continue;
    double sec;
    if (timeData != null && i < timeData.length) {
      final t = timeData[i];
      sec = t is num ? t.toDouble() : i.toDouble();
    } else {
      sec = i.toDouble();
    }
    out.add(ActivityHrPoint(sec, hr.toDouble()));
  }
  return out.length >= 2 ? out : null;
}
