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
  final String source; // 'strava' | 'garmin' | 'dual' | 'unknown'
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
  final String? garminActivityId;
  final String? stravaActivityId;
  @JsonKey(name: 'garmin_raw')
  final Map<String, dynamic>? garminRaw;
  @JsonKey(name: 'strava_raw')
  final Map<String, dynamic>? stravaRaw;

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
    this.garminActivityId,
    this.stravaActivityId,
    this.garminRaw,
    this.stravaRaw,
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
      'Attività';
  String? get stravaActivityName =>
      activityName ??
      stravaRaw?['name'] ??
      raw?['name'] ??
      garminRaw?['activityName']?.toString();
  String? get stravaDeviceName =>
      deviceName ?? stravaRaw?['device_name'] ?? raw?['device_name'];
  double? get stravaElevationGainM =>
      elevationGainM ??
      (stravaRaw?['total_elevation_gain'] as num?)?.toDouble() ??
      (raw?['total_elevation_gain'] as num?)?.toDouble();
  double? get stravaAvgHeartrate =>
      avgHeartrate ??
      (stravaRaw?['average_heartrate'] as num?)?.toDouble() ??
      (raw?['average_heartrate'] as num?)?.toDouble() ??
      (garminRaw?['averageHR'] as num?)?.toDouble() ??
      (garminRaw?['averageHeartRate'] as num?)?.toDouble();
  double? get stravaMaxHeartrate =>
      maxHeartrate ??
      (stravaRaw?['max_heartrate'] as num?)?.toDouble() ??
      (raw?['max_heartrate'] as num?)?.toDouble() ??
      (garminRaw?['maxHR'] as num?)?.toDouble() ??
      (garminRaw?['maxHeartRate'] as num?)?.toDouble();
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
    return elapsedMinutes ??
        (stravaElapsedSec != null ? stravaElapsedSec / 60.0 : null) ??
        (garminElapsedSec != null ? garminElapsedSec / 60.0 : null) ??
        activeMinutes ??
        0.0;
  }

  bool get containsStravaData =>
      hasStrava ||
      source == 'strava' ||
      source == 'dual' ||
      stravaActivityId != null;

  int? get detailActivityId {
    final rawId =
        stravaActivityId ??
        (id.startsWith('strava_') ? id.replaceFirst('strava_', '') : null);
    return rawId != null ? int.tryParse(rawId) : null;
  }
}
