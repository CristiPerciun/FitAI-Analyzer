import 'dart:math' as math;

/// Punto serie temporale da `garmin_raw` / `activityDetailMetrics` (Garmin Connect `activity/{id}/details`).
class GarminChartPoint {
  const GarminChartPoint(this.elapsedSeconds, this.value);

  final double elapsedSeconds;
  final double value;
}

/// Zone FC: indice zona 1..5 e secondi nella zona.
class GarminHrZoneSegment {
  const GarminHrZoneSegment(this.zoneIndex, this.seconds);

  final int zoneIndex;
  final double seconds;
}

/// Lap con durata e FC media (da `lapDTOs` / `laps`).
class GarminLapSummary {
  const GarminLapSummary({
    required this.lapIndex,
    required this.durationSec,
    this.avgHeartRate,
    this.distanceM,
  });

  final int lapIndex;
  final double durationSec;
  final double? avgHeartRate;
  final double? distanceM;
}

List<GarminChartPoint> downsampleGarminChartPoints(
  List<GarminChartPoint> data, {
  int maxPoints = 360,
}) {
  if (data.length <= maxPoints) return data;
  final step = data.length / maxPoints;
  final out = <GarminChartPoint>[];
  for (var i = 0; i < maxPoints; i++) {
    final idx = math.min((i * step).floor(), data.length - 1);
    out.add(data[idx]);
  }
  return out;
}

/// Sceglie il blocco JSON più ricco (risposta `get_activity_details` vs lista leggera).
Map<String, dynamic>? pickGarminChartPayload(Map<String, dynamic>? raw) {
  if (raw == null || raw.isEmpty) return null;
  Map<String, dynamic>? best = raw;
  var bestScore = _chartRichnessScore(raw);

  void walk(Map<String, dynamic> m) {
    final s = _chartRichnessScore(m);
    if (s > bestScore) {
      bestScore = s;
      best = m;
    }
    for (final k in const [
      'details',
      'detail',
      'activityDetails',
      'activity_detail',
      'fullDetail',
      'garminDetail',
    ]) {
      final v = m[k];
      if (v is Map) walk(Map<String, dynamic>.from(v));
    }
  }

  walk(raw);
  return best;
}

int _chartRichnessScore(Map<String, dynamic> m) {
  var score = 0;
  final adm = m['activityDetailMetrics'];
  if (adm is List) {
    for (final e in adm) {
      if (e is Map && e['metrics'] is List) {
        score += (e['metrics'] as List).length;
      }
    }
  }
  final samples = m['samples'];
  if (samples is List) score += samples.length;
  return score;
}

double _readSecondsForSample(Map<String, dynamic> m, {required int fallbackIndex}) {
  for (final k in const [
    'clockDurationInSeconds',
    'timerDurationInSeconds',
    'startTimeInSeconds',
    'elapsedSeconds',
    'timeOffsetInSeconds',
    'second',
    'timestampOffsetInSeconds',
  ]) {
    final v = m[k];
    if (v is num) return v.toDouble();
  }
  return fallbackIndex.toDouble();
}

double? _readYFromPoint(Map<String, dynamic> m, String? metricKey, {String? altKey}) {
  final v = m['value'];
  if (v is num && v > 0) return v.toDouble();
  if (metricKey != null && metricKey.isNotEmpty) {
    final direct = m[metricKey];
    if (direct is num && direct > 0) return direct.toDouble();
    for (final k in m.keys) {
      if (k.toString().toLowerCase() == metricKey.toLowerCase()) {
        final n = m[k];
        if (n is num && n > 0) return n.toDouble();
      }
    }
  }
  if (altKey != null) {
    final n = m[altKey];
    if (n is num && n > 0) return n.toDouble();
  }
  return null;
}

List<GarminChartPoint> _seriesFromActivityDetailMetrics(
  Map<String, dynamic> payload, {
  required bool Function(String metricKeyLower) keyFilter,
  required double? Function(Map<String, dynamic> point, String? metricKey) readY,
}) {
  final adm = payload['activityDetailMetrics'];
  if (adm is! List) return const [];

  final out = <GarminChartPoint>[];
  for (final block in adm) {
    if (block is! Map) continue;
    final b = Map<String, dynamic>.from(block);
    final metricKey = (b['metricKey'] ?? b['key'] ?? '').toString();
    final kl = metricKey.toLowerCase();
    if (!keyFilter(kl)) continue;

    final metrics = b['metrics'];
    if (metrics is! List) continue;
    for (var i = 0; i < metrics.length; i++) {
      final item = metrics[i];
      if (item is! Map) continue;
      final m = Map<String, dynamic>.from(item);
      final y = readY(m, metricKey.isEmpty ? null : metricKey);
      if (y == null || y <= 0 || y.isNaN) continue;
      final sec = _readSecondsForSample(m, fallbackIndex: i);
      out.add(GarminChartPoint(sec, y));
    }
  }
  return out.length >= 2 ? out : const [];
}

double? _readBpm(Map<String, dynamic> m) {
  for (final k in const [
    'heartRate',
    'heart_rate',
    'avgHeartRate',
    'averageHeartRate',
    'directHeartRate',
    'value',
    'bpm',
  ]) {
    final v = m[k];
    if (v is num && v > 0) return v.toDouble();
  }
  return null;
}

List<GarminChartPoint> _legacyHrFromNestedLists(Map<String, dynamic> raw) {
  for (final key in const [
    'timeSeries',
    'hrTimeSeries',
    'heartRateTimeSeries',
    'metrics',
  ]) {
    final v = raw[key];
    if (v is! List || v.length < 2) continue;
    final out = <GarminChartPoint>[];
    for (var i = 0; i < v.length; i++) {
      final e = v[i];
      if (e is! Map) continue;
      final m = Map<String, dynamic>.from(e);
      final bpm = _readBpm(m);
      if (bpm == null) continue;
      final sec = _readSecondsForSample(m, fallbackIndex: i);
      out.add(GarminChartPoint(sec, bpm));
    }
    if (out.length >= 2) return out;
  }
  return const [];
}

List<GarminChartPoint> _legacyHrFromSamples(Map<String, dynamic> raw) {
  final samples = raw['samples'];
  if (samples is! List) return const [];
  final out = <GarminChartPoint>[];
  for (var i = 0; i < samples.length; i++) {
    final s = samples[i];
    if (s is! Map) continue;
    final m = Map<String, dynamic>.from(s);
    final bpm = _readBpm(m);
    if (bpm == null) continue;
    final sec = _readSecondsForSample(m, fallbackIndex: i);
    out.add(GarminChartPoint(sec, bpm));
  }
  return out.length >= 2 ? out : const [];
}

List<double>? _readNumList(dynamic v) {
  if (v is! List) return null;
  final out = <double>[];
  for (final e in v) {
    if (e is num && e > 0) out.add(e.toDouble());
  }
  return out.length >= 2 ? out : null;
}

List<GarminChartPoint> _legacyHrFlatLists(Map<String, dynamic> raw) {
  final flatHr = _readNumList(raw['hrValues']) ??
      _readNumList(raw['heartRateValues']) ??
      _readNumList(raw['heartRates']);
  if (flatHr == null) return const [];
  return List<GarminChartPoint>.generate(
    flatHr.length,
    (i) => GarminChartPoint(i.toDouble(), flatHr[i]),
  );
}

/// FC: `activityDetailMetrics` (python-garminconnect `get_activity_details`) + fallback campioni legacy.
List<GarminChartPoint> extractGarminHeartRateSeries(Map<String, dynamic>? raw) {
  final payload = pickGarminChartPayload(raw);
  if (payload != null) {
    final fromAdm = _seriesFromActivityDetailMetrics(
      payload,
      keyFilter: (k) =>
          k.contains('heartrate') ||
          k.contains('heart_rate') ||
          k == 'hr' ||
          k.contains('heart'),
      readY: (m, mk) => _readYFromPoint(m, mk, altKey: 'directHeartRate'),
    );
    if (fromAdm.isNotEmpty) return fromAdm;

    final nested = _legacyHrFromNestedLists(payload);
    if (nested.isNotEmpty) return nested;

    final samples = _legacyHrFromSamples(payload);
    if (samples.isNotEmpty) return samples;

    final flat = _legacyHrFlatLists(payload);
    if (flat.isNotEmpty) return flat;
  }

  if (raw == null || raw.isEmpty) return const [];
  final nestedRoot = _legacyHrFromNestedLists(raw);
  if (nestedRoot.isNotEmpty) return nestedRoot;
  final samplesRoot = _legacyHrFromSamples(raw);
  if (samplesRoot.isNotEmpty) return samplesRoot;
  return _legacyHrFlatLists(raw);
}

/// Velocità in km/h (spesso m/s in Garmin).
List<GarminChartPoint> extractGarminSpeedSeriesKmh(Map<String, dynamic>? raw) {
  final payload = pickGarminChartPayload(raw);
  if (payload == null) return const [];

  return _seriesFromActivityDetailMetrics(
    payload,
    keyFilter: (k) =>
        (k.contains('speed') || k == 'directspeed') && !k.contains('vertical'),
    readY: (m, mk) {
      final y = _readYFromPoint(m, mk, altKey: 'directSpeed');
      if (y == null) return null;
      if (y < 55) return y * 3.6;
      return y;
    },
  );
}

/// Altitudine (metri).
List<GarminChartPoint> extractGarminElevationSeriesM(Map<String, dynamic>? raw) {
  final payload = pickGarminChartPayload(raw);
  if (payload == null) return const [];

  return _seriesFromActivityDetailMetrics(
    payload,
    keyFilter: (k) =>
        k.contains('elevation') ||
        k.contains('altitude') ||
        k.contains('directelevation') ||
        k.contains('directaltitude'),
    readY: (m, mk) => _readYFromPoint(m, mk, altKey: 'directElevation'),
  );
}

int _readZoneIndex(Map<String, dynamic> zm) {
  for (final k in const [
    'zoneNumber',
    'zone',
    'hrZone',
    'heartRateZone',
    'zoneId',
  ]) {
    final v = zm[k];
    if (v is int) return v;
    if (v is num) return v.toInt();
  }
  return 0;
}

double? _readZoneSeconds(Map<String, dynamic> zm) {
  for (final k in const [
    'secsInZone',
    'timeInSeconds',
    'seconds',
    'duration',
    'time',
  ]) {
    final v = zm[k];
    if (v is num && v > 0) return v.toDouble();
  }
  return null;
}

/// Tempo in zone FC (ricerca ricorsiva di liste di DTO zona).
List<GarminHrZoneSegment> extractGarminHrZoneSegments(Map<String, dynamic>? raw) {
  if (raw == null || raw.isEmpty) return const [];
  final out = <GarminHrZoneSegment>[];

  void tryList(List<dynamic> list) {
    if (list.isEmpty || list.first is! Map) return;
    final fm = Map<String, dynamic>.from(list.first as Map);
    final z0 = _readZoneIndex(fm);
    final s0 = _readZoneSeconds(fm);
    if (z0 < 1 || z0 > 6 || s0 == null) return;
    for (final e in list) {
      if (e is! Map) continue;
      final zm = Map<String, dynamic>.from(e);
      final z = _readZoneIndex(zm);
      final s = _readZoneSeconds(zm);
      if (z >= 1 && z <= 6 && s != null && s > 0) {
        out.add(GarminHrZoneSegment(z, s));
      }
    }
  }

  void walk(dynamic node) {
    if (node is Map) {
      for (final v in node.values) {
        if (v is List) {
          tryList(v);
        }
        walk(v);
      }
    } else if (node is List) {
      for (final e in node) {
        walk(e);
      }
    }
  }

  walk(raw);
  out.sort((a, b) => a.zoneIndex.compareTo(b.zoneIndex));
  return out;
}

double? _firstPositiveNum(Map<String, dynamic> m, List<String> keys) {
  for (final k in keys) {
    final v = m[k];
    if (v is num && v > 0) return v.toDouble();
  }
  return null;
}

/// Lap da `lapDTOs` / `laps`.
List<GarminLapSummary> extractGarminLaps(Map<String, dynamic>? raw) {
  final payload = pickGarminChartPayload(raw) ?? raw;
  if (payload == null || payload.isEmpty) return const [];

  for (final key in const ['lapDTOs', 'laps', 'lapDtos']) {
    final v = payload[key];
    if (v is! List || v.length < 2) continue;
    final out = <GarminLapSummary>[];
    for (var i = 0; i < v.length; i++) {
      final e = v[i];
      if (e is! Map) continue;
      final m = Map<String, dynamic>.from(e);
      final dur = _firstPositiveNum(m, const [
            'duration',
            'elapsedDuration',
            'movingDuration',
          ]) ??
          0.0;
      if (dur <= 0) continue;
      final hr = _firstPositiveNum(m, const [
        'averageHR',
        'averageHeartRate',
        'avgHR',
        'averageHr',
      ]);
      final dist = _firstPositiveNum(m, const ['distance', 'distanceMeters']);
      out.add(GarminLapSummary(
        lapIndex: (m['lapIndex'] as num?)?.toInt() ?? i + 1,
        durationSec: dur,
        avgHeartRate: hr,
        distanceM: dist,
      ));
    }
    if (out.length >= 2) return out;
  }
  return const [];
}

double maxYWithPadding(Iterable<double> values, {double padFraction = 0.12}) {
  final mx = values.fold<double>(0, (a, b) => math.max(a, b));
  return mx <= 0 ? 1 : mx * (1 + padFraction);
}
