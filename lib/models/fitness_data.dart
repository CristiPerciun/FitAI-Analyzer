import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:json_annotation/json_annotation.dart';

part 'fitness_data.g.dart';

/// Modello per dati fitness da Strava (e altre fonti future).
/// Estendere con campi specifici per ogni fonte.
@JsonSerializable()
class FitnessData {
  @JsonKey(defaultValue: '')
  final String id;
  @JsonKey(defaultValue: 'unknown')
  final String source; // 'strava' | 'health'
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
      activityType ?? raw?['sport_type'] ?? raw?['type'] ?? 'Attività';
  String? get stravaActivityName => activityName ?? raw?['name'];
  String? get stravaDeviceName => deviceName ?? raw?['device_name'];
  double? get stravaElevationGainM =>
      elevationGainM ?? (raw?['total_elevation_gain'] as num?)?.toDouble();
  double? get stravaAvgHeartrate =>
      avgHeartrate ?? (raw?['average_heartrate'] as num?)?.toDouble();
  double? get stravaMaxHeartrate =>
      maxHeartrate ?? (raw?['max_heartrate'] as num?)?.toDouble();
  double? get stravaAvgSpeedKmh {
    if (avgSpeedKmh != null) return avgSpeedKmh;
    final avgSpeed = (raw?['average_speed'] as num?)?.toDouble();
    return avgSpeed != null ? avgSpeed * 3.6 : null;
  }
  double get stravaElapsedMinutes =>
      elapsedMinutes ?? (raw?['elapsed_time'] as num?)?.toDouble() ?? activeMinutes ?? 0.0;
}
