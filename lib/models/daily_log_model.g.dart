// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'daily_log_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

DailyLogModel _$DailyLogModelFromJson(Map<String, dynamic> json) =>
    DailyLogModel(
      date: json['date'] as String,
      stravaActivities:
          (json['strava_activities'] as List<dynamic>?)
              ?.map((e) => e as Map<String, dynamic>)
              .toList() ??
          [],
      garminActivities:
          (json['garmin_activities'] as List<dynamic>?)
              ?.map((e) => e as Map<String, dynamic>)
              .toList() ??
          [],
      nutritionGemini: json['nutrition_gemini'] as Map<String, dynamic>? ?? {},
      nutritionSummary:
          json['nutrition_summary'] as Map<String, dynamic>? ?? {},
      totalBurnedKcal: (json['total_burned_kcal'] as num?)?.toDouble() ?? 0.0,
      weightKg: (json['weight_kg'] as num?)?.toDouble(),
      goalTodayIa: json['goal_today_ia'] as String? ?? '',
      timestamp: DailyLogModel._timestampFromJson(json['timestamp']),
    );

Map<String, dynamic> _$DailyLogModelToJson(DailyLogModel instance) =>
    <String, dynamic>{
      'date': instance.date,
      'strava_activities': instance.stravaActivities,
      'garmin_activities': instance.garminActivities,
      'nutrition_gemini': instance.nutritionGemini,
      'nutrition_summary': instance.nutritionSummary,
      'total_burned_kcal': instance.totalBurnedKcal,
      'weight_kg': instance.weightKg,
      'goal_today_ia': instance.goalTodayIa,
      'timestamp': DailyLogModel._timestampToJson(instance.timestamp),
    };
