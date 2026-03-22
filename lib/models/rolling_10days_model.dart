import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:json_annotation/json_annotation.dart';

part 'rolling_10days_model.g.dart';

/// Livello 2 - Rolling 10 giorni (rolling_10days/current).
/// Aggregati pre-calcolati degli ultimi 10 giorni per prompt AI veloci.
@JsonSerializable()
class Rolling10DaysModel {
  /// Riepilogo attività per ciascuno dei 10 giorni.
  @JsonKey(name: 'activities_summary', fromJson: _activitiesSummaryFromJson)
  final List<Map<String, dynamic>> activitiesSummary;

  /// Distanza totale km.
  @JsonKey(name: 'total_distance_km')
  final double totalDistanceKm;

  /// Minuti totali in Zone 2 (Peter Attia).
  @JsonKey(name: 'total_zone2_minutes')
  final int totalZone2Minutes;

  /// Frequenza cardiaca media.
  @JsonKey(name: 'avg_hr')
  final double avgHr;

  /// Medie macro: protein_g, carbs_g, fat_g, calories.
  @JsonKey(name: 'macro_averages', defaultValue: {})
  final Map<String, double> macroAverages;

  /// VO2max stimato.
  @JsonKey(name: 'estimated_vo2_max')
  final double estimatedVo2Max;

  @JsonKey(name: 'last_updated', fromJson: _dateFromJson, toJson: _dateToJson)
  final DateTime lastUpdated;

  const Rolling10DaysModel({
    required this.activitiesSummary,
    required this.totalDistanceKm,
    required this.totalZone2Minutes,
    required this.avgHr,
    required this.macroAverages,
    required this.estimatedVo2Max,
    required this.lastUpdated,
  });

  factory Rolling10DaysModel.fromJson(Map<String, dynamic> json) =>
      _$Rolling10DaysModelFromJson(json);

  Map<String, dynamic> toJson() => _$Rolling10DaysModelToJson(this);

  static DateTime _dateFromJson(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is String) return DateTime.tryParse(value) ?? DateTime.now();
    return DateTime.now();
  }

  static Object _dateToJson(DateTime date) => Timestamp.fromDate(date);

  static List<Map<String, dynamic>> _activitiesSummaryFromJson(Object? json) {
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
}
