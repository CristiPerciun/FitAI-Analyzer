import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:json_annotation/json_annotation.dart';

part 'fitness_data.g.dart';

/// Modello per dati fitness da Garmin/Apple Health.
/// Estendere con campi specifici per ogni fonte.
@JsonSerializable()
class FitnessData {
  @JsonKey(defaultValue: '')
  final String id;
  @JsonKey(defaultValue: 'unknown')
  final String source; // 'garmin' | 'health'
  @JsonKey(fromJson: _dateFromJson, toJson: _dateToJson)
  final DateTime date;
  final double? calories;
  final double? steps;
  final double? distanceKm;
  final double? activeMinutes;
  final Map<String, dynamic>? raw;

  const FitnessData({
    required this.id,
    required this.source,
    required this.date,
    this.calories,
    this.steps,
    this.distanceKm,
    this.activeMinutes,
    this.raw,
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
}
