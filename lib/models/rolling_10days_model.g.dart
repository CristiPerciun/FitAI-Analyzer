// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'rolling_10days_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Rolling10DaysModel _$Rolling10DaysModelFromJson(Map<String, dynamic> json) =>
    Rolling10DaysModel(
      activitiesSummary: Rolling10DaysModel._activitiesSummaryFromJson(
        json['activities_summary'],
      ),
      totalDistanceKm: (json['total_distance_km'] as num).toDouble(),
      totalZone2Minutes: (json['total_zone2_minutes'] as num).toInt(),
      avgHr: (json['avg_hr'] as num).toDouble(),
      macroAverages:
          (json['macro_averages'] as Map<String, dynamic>?)?.map(
            (k, e) => MapEntry(k, (e as num).toDouble()),
          ) ??
          {},
      estimatedVo2Max: (json['estimated_vo2_max'] as num).toDouble(),
      lastUpdated: Rolling10DaysModel._dateFromJson(json['last_updated']),
    );

Map<String, dynamic> _$Rolling10DaysModelToJson(Rolling10DaysModel instance) =>
    <String, dynamic>{
      'activities_summary': instance.activitiesSummary,
      'total_distance_km': instance.totalDistanceKm,
      'total_zone2_minutes': instance.totalZone2Minutes,
      'avg_hr': instance.avgHr,
      'macro_averages': instance.macroAverages,
      'estimated_vo2_max': instance.estimatedVo2Max,
      'last_updated': Rolling10DaysModel._dateToJson(instance.lastUpdated),
    };
