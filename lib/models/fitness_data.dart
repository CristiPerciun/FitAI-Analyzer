import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:json_annotation/json_annotation.dart';

part 'fitness_data.g.dart';

/// Modello per dati fitness da Strava (e altre fonti future).
/// Usato dalla UI per attività unificate (`activities`) e retrocompatibilità.
@JsonSerializable()
class FitnessData {
  @JsonKey(defaultValue: '')
  final String id;
  @JsonKey(defaultValue: 'unknown')
  final String source; // 'strava' | 'garmin' | 'dual' | 'mi_fitness' | 'unknown'
  @JsonKey(fromJson: _dateFromJson, toJson: _dateToJson)
  final DateTime date;
  final double? calories;
  final double? steps;
  final double? distanceKm;
  final double? activeMinutes;
  final Map<String, dynamic>? raw;

  /// Campi Strava (sport_type, name, device, elevation, HR, speed)
  final String? activityType;
  final String? activityName;
  final String? deviceName;
  final double? elevationGainM;
  final double? avgHeartrate;
  final double? maxHeartrate;
  final double? avgSpeedKmh;
  final double? elapsedMinutes;
  @JsonKey(defaultValue: false)
  final bool hasGarmin;
  @JsonKey(defaultValue: false)
  final bool hasStrava;
  @JsonKey(defaultValue: false)
  final bool hasMiFitness;
  final String? garminActivityId;
  final String? stravaActivityId;
  final String? miFitnessTrackId;
  @JsonKey(name: 'garmin_raw')
  final Map<String, dynamic>? garminRaw;
  @JsonKey(name: 'strava_raw')
  final Map<String, dynamic>? stravaRaw;
  @JsonKey(name: 'mi_fitness_raw')
  final Map<String, dynamic>? miFitnessRaw;

  const FitnessData({
    required this.id,
    required this.source,
    required this.date,
    this.calories,
    this.steps,
    this.distanceKm,
    this.activeMinutes,
    this.raw,
    this.activityType,
    this.activityName,
    this.deviceName,
    this.elevationGainM,
    this.avgHeartrate,
    this.maxHeartrate,
    this.avgSpeedKmh,
    this.elapsedMinutes,
    this.hasGarmin = false,
    this.hasStrava = false,
    this.hasMiFitness = false,
    this.garminActivityId,
    this.stravaActivityId,
    this.miFitnessTrackId,
    this.garminRaw,
    this.stravaRaw,
    this.miFitnessRaw,
  });

  factory FitnessData.fromJson(Map<String, dynamic> json) =>
      _$FitnessDataFromJson(json);

  Map<String, dynamic> toJson() => _$FitnessDataToJson(this);

  static DateTime _dateFromJson(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is String) return DateTime.tryParse(value) ?? DateTime.now();
    return DateTime.now();
  }

  static Object _dateToJson(DateTime date) => Timestamp.fromDate(date);

  static double? _dynamicToDouble(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString().trim().replaceAll(',', '.'));
  }

  /// Token tipo allenamento da campo Huami `type` (summary) quando manca `activityType`.
  static String? _miHuamiSportToken(dynamic typeId) {
    if (typeId == null) return null;
    final n = int.tryParse(typeId.toString());
    if (n == null) return typeId.toString().toLowerCase();
    const m = <int, String>{
      1: 'run',
      2: 'walk',
      3: 'ride',
      4: 'hike',
      5: 'run',
      6: 'ride',
      7: 'walk',
      8: 'run',
      9: 'hike',
      10: 'workout',
      11: 'swim',
      12: 'swim',
      14: 'workout',
      15: 'swim',
      16: 'swim',
      19: 'workout',
      21: 'workout',
      24: 'workout',
      27: 'workout',
      28: 'workout',
      30: 'run',
      31: 'ride',
      32: 'walk',
    };
    return m[n] ?? 'sport$n';
  }

  /// Campi Strava con fallback da raw (per dati salvati prima dell'aggiornamento)
  String get stravaActivityType =>
      activityType ??
      stravaRaw?['sport_type'] ??
      stravaRaw?['type'] ??
      raw?['sport_type'] ??
      raw?['type'] ??
      garminRaw?['activityTypeKey']?.toString() ??
      (garminRaw?['activityType'] is Map
          ? (garminRaw?['activityType']['typeKey'] ??
                    garminRaw?['activityType']['typeId'])
                ?.toString()
          : garminRaw?['activityType']?.toString()) ??
      _miHuamiSportToken(miFitnessRaw?['type']) ??
      'Attività';
  String? get stravaActivityName =>
      activityName ??
      stravaRaw?['name'] ??
      raw?['name'] ??
      garminRaw?['activityName']?.toString() ??
      (miFitnessRaw?['location'] as String?) ??
      (miFitnessRaw?['city'] as String?);
  String? get stravaDeviceName =>
      deviceName ??
      stravaRaw?['device_name'] ??
      raw?['device_name'] ??
      miFitnessRaw?['bind_device']?.toString();
  double? get stravaElevationGainM =>
      elevationGainM ??
      (stravaRaw?['total_elevation_gain'] as num?)?.toDouble() ??
      (raw?['total_elevation_gain'] as num?)?.toDouble() ??
      _dynamicToDouble(miFitnessRaw?['altitude_ascend']);
  double? get stravaAvgHeartrate =>
      avgHeartrate ??
      (stravaRaw?['average_heartrate'] as num?)?.toDouble() ??
      (raw?['average_heartrate'] as num?)?.toDouble() ??
      (garminRaw?['averageHR'] as num?)?.toDouble() ??
      (garminRaw?['averageHeartRate'] as num?)?.toDouble() ??
      _dynamicToDouble(miFitnessRaw?['avg_heart_rate']);
  double? get stravaMaxHeartrate =>
      maxHeartrate ??
      (stravaRaw?['max_heartrate'] as num?)?.toDouble() ??
      (raw?['max_heartrate'] as num?)?.toDouble() ??
      (garminRaw?['maxHR'] as num?)?.toDouble() ??
      (garminRaw?['maxHeartRate'] as num?)?.toDouble() ??
      _dynamicToDouble(miFitnessRaw?['max_heart_rate']);
  double? get stravaAvgSpeedKmh {
    if (avgSpeedKmh != null) return avgSpeedKmh;
    final avgSpeed =
        (stravaRaw?['average_speed'] as num?)?.toDouble() ??
        (raw?['average_speed'] as num?)?.toDouble();
    return avgSpeed != null ? avgSpeed * 3.6 : null;
  }

  double get stravaElapsedMinutes {
    final stravaElapsedSec =
        (stravaRaw?['elapsed_time'] as num?)?.toDouble() ??
        (raw?['elapsed_time'] as num?)?.toDouble();
    final garminElapsedSec =
        (garminRaw?['duration'] as num?)?.toDouble() ??
        (garminRaw?['movingDuration'] as num?)?.toDouble();
    final miRunSec = _dynamicToDouble(miFitnessRaw?['run_time']);
    return elapsedMinutes ??
        (stravaElapsedSec != null ? stravaElapsedSec / 60.0 : null) ??
        (garminElapsedSec != null ? garminElapsedSec / 60.0 : null) ??
        (miRunSec != null ? miRunSec / 60.0 : null) ??
        activeMinutes ??
        0.0;
  }

  bool get containsStravaData =>
      hasStrava ||
      source == 'strava' ||
      source == 'dual' ||
      stravaActivityId != null;

  bool get containsMiFitnessData =>
      hasMiFitness ||
      source == 'mi_fitness' ||
      miFitnessTrackId != null ||
      miFitnessRaw != null;

  int? get detailActivityId {
    final rawId =
        stravaActivityId ??
        (id.startsWith('strava_') ? id.replaceFirst('strava_', '') : null);
    return rawId != null ? int.tryParse(rawId) : null;
  }
}
