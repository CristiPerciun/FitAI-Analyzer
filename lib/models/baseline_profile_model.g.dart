// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'baseline_profile_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

BaselineProfileModel _$BaselineProfileModelFromJson(
  Map<String, dynamic> json,
) => BaselineProfileModel(
  goal: json['goal'] as String,
  annualStats: json['annual_stats'] as Map<String, dynamic>,
  monthlyTrends: (json['monthly_trends'] as List<dynamic>)
      .map((e) => e as Map<String, dynamic>)
      .toList(),
  keyMetricsAttia: json['key_metrics_attia'] as Map<String, dynamic>,
  evolutionNotes: json['evolution_notes'] as String,
  aiReadySummary: json['ai_ready_summary'] as String,
  lastBaselineUpdate: BaselineProfileModel._dateFromJson(
    json['last_baseline_update'],
  ),
  references:
      (json['references'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList() ??
      const [],
);

Map<String, dynamic> _$BaselineProfileModelToJson(
  BaselineProfileModel instance,
) => <String, dynamic>{
  'goal': instance.goal,
  'annual_stats': instance.annualStats,
  'monthly_trends': instance.monthlyTrends,
  'key_metrics_attia': instance.keyMetricsAttia,
  'evolution_notes': instance.evolutionNotes,
  'ai_ready_summary': instance.aiReadySummary,
  'last_baseline_update': BaselineProfileModel._dateToJson(
    instance.lastBaselineUpdate,
  ),
  'references': instance.references,
};
