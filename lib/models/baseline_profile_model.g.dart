// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'baseline_profile_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

BaselineProfileModel _$BaselineProfileModelFromJson(
  Map<String, dynamic> json,
) => BaselineProfileModel(
  goalIa: json['goal_ia'] as String? ?? '',
  annualStats: BaselineProfileModel._mapFromJson(json['annual_stats']),
  monthlyTrends: BaselineProfileModel._monthlyTrendsFromJson(
    json['monthly_trends'],
  ),
  keyMetricsAttia: BaselineProfileModel._mapFromJson(json['key_metrics_attia']),
  evolutionNotes: BaselineProfileModel._stringFromJson(json['evolution_notes']),
  aiReadySummary: BaselineProfileModel._stringFromJson(
    json['ai_ready_summary'],
  ),
  lastBaselineUpdate: BaselineProfileModel._dateFromJson(
    json['last_baseline_update'],
  ),
  references:
      (json['references'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList() ??
      const [],
  bmrKcal: (json['bmr_kcal'] as num?)?.toDouble(),
  tdeeKcal: (json['tdee_kcal'] as num?)?.toDouble(),
  activityMultiplier: (json['activity_multiplier'] as num?)?.toDouble(),
  activityLevelDerived: json['activity_level_derived'] as String?,
  nutritionCalorieTarget: (json['nutrition_calorie_target'] as num?)
      ?.toDouble(),
  nutritionEnergyAdjustmentFraction:
      (json['nutrition_energy_adjustment_fraction'] as num?)?.toDouble(),
  nutritionGoalSnapshot: BaselineProfileModel._nullableMapFromJson(
    json['nutrition_goal_snapshot'],
  ),
);

Map<String, dynamic> _$BaselineProfileModelToJson(
  BaselineProfileModel instance,
) => <String, dynamic>{
  'goal_ia': instance.goalIa,
  'annual_stats': instance.annualStats,
  'monthly_trends': instance.monthlyTrends,
  'key_metrics_attia': instance.keyMetricsAttia,
  'evolution_notes': instance.evolutionNotes,
  'ai_ready_summary': instance.aiReadySummary,
  'last_baseline_update': BaselineProfileModel._dateToJson(
    instance.lastBaselineUpdate,
  ),
  'references': instance.references,
  'bmr_kcal': ?instance.bmrKcal,
  'tdee_kcal': ?instance.tdeeKcal,
  'activity_multiplier': ?instance.activityMultiplier,
  'activity_level_derived': ?instance.activityLevelDerived,
  'nutrition_calorie_target': ?instance.nutritionCalorieTarget,
  'nutrition_energy_adjustment_fraction':
      ?instance.nutritionEnergyAdjustmentFraction,
  'nutrition_goal_snapshot': ?instance.nutritionGoalSnapshot,
};
