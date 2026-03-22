import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:json_annotation/json_annotation.dart';

part 'baseline_profile_model.g.dart';

/// Livello 3 - Profilo baseline annuale (baseline_profile/main).
/// Profilo evolutivo aggiornato ogni 10 giorni, pronto per prompt AI.
@JsonSerializable(includeIfNull: false)
class BaselineProfileModel {
  /// Obiettivo prevalente creato dall'IA (derivato da goal_today_ia dei daily_logs).
  @JsonKey(name: 'goal_ia', defaultValue: '')
  final String goalIa;

  /// Statistiche annuali: total_km_2026, total_workouts, avg_weight, etc.
  @JsonKey(name: 'annual_stats', fromJson: _mapFromJson)
  final Map<String, dynamic> annualStats;

  /// Trend mensili (12 oggetti con progressione).
  @JsonKey(name: 'monthly_trends', fromJson: _monthlyTrendsFromJson)
  final List<Map<String, dynamic>> monthlyTrends;

  /// Metriche chiave stile Peter Attia (Outlive).
  @JsonKey(name: 'key_metrics_attia', fromJson: _mapFromJson)
  final Map<String, dynamic> keyMetricsAttia;

  /// Note evolutive: "Da gennaio a marzo hai perso 2,8 kg..."
  @JsonKey(name: 'evolution_notes', fromJson: _stringFromJson)
  final String evolutionNotes;

  /// Testo pre-costruito (4000+ caratteri) pronto per prompt AI.
  @JsonKey(name: 'ai_ready_summary', fromJson: _stringFromJson)
  final String aiReadySummary;

  @JsonKey(name: 'last_baseline_update', fromJson: _dateFromJson, toJson: _dateToJson)
  final DateTime lastBaselineUpdate;

  /// Riferimenti: "Outlive - Zone 2", "Università Stanford VO2max study", etc.
  final List<String> references;

  // --- Nutrizione / TDEE (da onboarding + NutritionGoal, merge su baseline_profile/main) ---

  @JsonKey(name: 'bmr_kcal')
  final double? bmrKcal;

  @JsonKey(name: 'tdee_kcal')
  final double? tdeeKcal;

  @JsonKey(name: 'activity_multiplier')
  final double? activityMultiplier;

  /// Livello attività derivato da `training_days_per_week` (es. `moderate`).
  @JsonKey(name: 'activity_level_derived')
  final String? activityLevelDerived;

  @JsonKey(name: 'nutrition_calorie_target')
  final double? nutritionCalorieTarget;

  /// Frazione su TDEE (es. -0.175 = -17.5% deficit).
  @JsonKey(name: 'nutrition_energy_adjustment_fraction')
  final double? nutritionEnergyAdjustmentFraction;

  /// Copia JSON dell’ultimo [NutritionGoal] salvato in profile/profile.
  @JsonKey(name: 'nutrition_goal_snapshot', fromJson: _nullableMapFromJson)
  final Map<String, dynamic>? nutritionGoalSnapshot;

  const BaselineProfileModel({
    required this.goalIa,
    required this.annualStats,
    required this.monthlyTrends,
    required this.keyMetricsAttia,
    required this.evolutionNotes,
    required this.aiReadySummary,
    required this.lastBaselineUpdate,
    this.references = const [],
    this.bmrKcal,
    this.tdeeKcal,
    this.activityMultiplier,
    this.activityLevelDerived,
    this.nutritionCalorieTarget,
    this.nutritionEnergyAdjustmentFraction,
    this.nutritionGoalSnapshot,
  });

  factory BaselineProfileModel.fromJson(Map<String, dynamic> json) =>
      _$BaselineProfileModelFromJson(json);

  Map<String, dynamic> toJson() => _$BaselineProfileModelToJson(this);

  static DateTime _dateFromJson(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is String) return DateTime.tryParse(value) ?? DateTime.now();
    return DateTime.now();
  }

  static Object _dateToJson(DateTime date) => Timestamp.fromDate(date);

  /// Firestore può avere campi assenti o esplicitamente null su doc parziali.
  static Map<String, dynamic> _mapFromJson(Object? json) {
    if (json is Map<String, dynamic>) return json;
    if (json is Map) return Map<String, dynamic>.from(json);
    return {};
  }

  static List<Map<String, dynamic>> _monthlyTrendsFromJson(Object? json) {
    if (json is! List) return [];
    final out = <Map<String, dynamic>>[];
    for (final e in json) {
      if (e is Map<String, dynamic>) {
        out.add(e);
      } else if (e is Map) {
        out.add(Map<String, dynamic>.from(e));
      }
    }
    return out;
  }

  static String _stringFromJson(Object? json) => json?.toString() ?? '';

  static Map<String, dynamic>? _nullableMapFromJson(Object? json) {
    if (json == null) return null;
    if (json is Map<String, dynamic>) return json;
    if (json is Map) return Map<String, dynamic>.from(json);
    return null;
  }
}
