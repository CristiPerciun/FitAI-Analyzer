import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:json_annotation/json_annotation.dart';

part 'daily_log_model.g.dart';

/// Livello 1 - Log giornaliero (daily_logs/{YYYY-MM-DD}).
/// Dati raw da Strava + Gemini (foto piatto) + peso opzionale.
@JsonSerializable()
class DailyLogModel {
  /// Data in formato YYYY-MM-DD (usata come doc ID).
  final String date;

  /// Attività Strava del giorno.
  @JsonKey(name: 'strava_activities', defaultValue: [])
  final List<Map<String, dynamic>> stravaActivities;

  /// Nutrizione da Gemini (foto piatto): total_calories, protein_g, carbs_g, etc.
  @JsonKey(name: 'nutrition_gemini', defaultValue: {})
  final Map<String, dynamic> nutritionGemini;

  /// Calorie bruciate totali (da attività).
  @JsonKey(name: 'total_burned_kcal', defaultValue: 0.0)
  final double totalBurnedKcal;

  /// Peso del giorno (opzionale).
  @JsonKey(name: 'weight_kg')
  final double? weightKg;

  /// Obiettivo del giorno: "dimagrire" o "massa_muscolare".
  @JsonKey(name: 'goal_today')
  final String goalToday;

  @JsonKey(fromJson: _timestampFromJson, toJson: _timestampToJson)
  final DateTime timestamp;

  const DailyLogModel({
    required this.date,
    required this.stravaActivities,
    required this.nutritionGemini,
    required this.totalBurnedKcal,
    this.weightKg,
    required this.goalToday,
    required this.timestamp,
  });

  factory DailyLogModel.fromJson(Map<String, dynamic> json) =>
      _$DailyLogModelFromJson(json);

  Map<String, dynamic> toJson() => _$DailyLogModelToJson(this);

  static DateTime _timestampFromJson(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is String) return DateTime.tryParse(value) ?? DateTime.now();
    return DateTime.now();
  }

  static Object _timestampToJson(DateTime date) => Timestamp.fromDate(date);
}
