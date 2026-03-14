import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:json_annotation/json_annotation.dart';

part 'daily_log_model.g.dart';

/// Livello 1 - Log giornaliero (daily_logs/{YYYY-MM-DD}).
/// Dati raw da Strava + Gemini (foto piatto) + peso opzionale.
/// Strategia Tre Livelli: nutrition_summary per Livello 2/3, meals subcollection per Livello 1.
@JsonSerializable()
class DailyLogModel {
  /// Data in formato YYYY-MM-DD (usata come doc ID).
  final String date;

  /// Attività Strava del giorno.
  @JsonKey(name: 'strava_activities', defaultValue: [])
  final List<Map<String, dynamic>> stravaActivities;

  /// Nutrizione da Gemini (foto piatto): total_calories, protein_g, carbs_g, etc.
  /// Retrocompatibilità: usato se nutrition_summary assente.
  @JsonKey(name: 'nutrition_gemini', defaultValue: {})
  final Map<String, dynamic> nutritionGemini;

  /// Sintesi nutrizione per Livello 2/3: total_kcal, total_protein, avg_longevity_score.
  /// L'IA legge solo questo per trend settimanale senza scaricare ogni pasto.
  @JsonKey(name: 'nutrition_summary', defaultValue: {})
  final Map<String, dynamic> nutritionSummary;

  /// Calorie bruciate totali (da attività).
  @JsonKey(name: 'total_burned_kcal', defaultValue: 0.0)
  final double totalBurnedKcal;

  /// Peso del giorno (opzionale).
  @JsonKey(name: 'weight_kg')
  final double? weightKg;

  /// Obiettivo del giorno creato dall'IA (L'app crea i goal giornalieri dal risultato AI).
  @JsonKey(name: 'goal_today_ia', defaultValue: '')
  final String goalTodayIa;

  @JsonKey(fromJson: _timestampFromJson, toJson: _timestampToJson)
  final DateTime timestamp;

  const DailyLogModel({
    required this.date,
    required this.stravaActivities,
    required this.nutritionGemini,
    this.nutritionSummary = const {},
    required this.totalBurnedKcal,
    this.weightKg,
    required this.goalTodayIa,
    required this.timestamp,
  });

  /// Nutrizione per prompt AI: preferisce nutrition_summary (Livello 2/3), fallback a nutrition_gemini.
  Map<String, dynamic> get nutritionForAi {
    if (nutritionSummary.isNotEmpty) {
      return {
        'total_calories': nutritionSummary['total_kcal'],
        'protein_g': nutritionSummary['total_protein'],
        'carbs_g': nutritionSummary['total_carbs'],
        'fat_g': nutritionSummary['total_fat'],
        'avg_longevity_score': nutritionSummary['avg_longevity_score'],
      };
    }
    return nutritionGemini;
  }

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
