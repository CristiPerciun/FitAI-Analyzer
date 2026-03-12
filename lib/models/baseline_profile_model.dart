import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:json_annotation/json_annotation.dart';

part 'baseline_profile_model.g.dart';

/// Livello 3 - Profilo baseline annuale (baseline_profile/main).
/// Profilo evolutivo aggiornato ogni 10 giorni, pronto per prompt AI.
@JsonSerializable()
class BaselineProfileModel {
  /// Obiettivo: "dimagrire" o "massa_muscolare".
  final String goal;

  /// Statistiche annuali: total_km_2026, total_workouts, avg_weight, etc.
  @JsonKey(name: 'annual_stats')
  final Map<String, dynamic> annualStats;

  /// Trend mensili (12 oggetti con progressione).
  @JsonKey(name: 'monthly_trends')
  final List<Map<String, dynamic>> monthlyTrends;

  /// Metriche chiave stile Peter Attia (Outlive).
  @JsonKey(name: 'key_metrics_attia')
  final Map<String, dynamic> keyMetricsAttia;

  /// Note evolutive: "Da gennaio a marzo hai perso 2,8 kg..."
  @JsonKey(name: 'evolution_notes')
  final String evolutionNotes;

  /// Testo pre-costruito (4000+ caratteri) pronto per prompt AI.
  @JsonKey(name: 'ai_ready_summary')
  final String aiReadySummary;

  @JsonKey(name: 'last_baseline_update', fromJson: _dateFromJson, toJson: _dateToJson)
  final DateTime lastBaselineUpdate;

  /// Riferimenti: "Outlive - Zone 2", "Università Stanford VO2max study", etc.
  final List<String> references;

  const BaselineProfileModel({
    required this.goal,
    required this.annualStats,
    required this.monthlyTrends,
    required this.keyMetricsAttia,
    required this.evolutionNotes,
    required this.aiReadySummary,
    required this.lastBaselineUpdate,
    this.references = const [],
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
}
