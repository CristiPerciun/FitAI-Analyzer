// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'fitness_data.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

FitnessData _$FitnessDataFromJson(Map<String, dynamic> json) => FitnessData(
  id: json['id'] as String? ?? '',
  source: json['source'] as String? ?? 'unknown',
  date: FitnessData._dateFromJson(json['date']),
  calories: (json['calories'] as num?)?.toDouble(),
  steps: (json['steps'] as num?)?.toDouble(),
  distanceKm: (json['distanceKm'] as num?)?.toDouble(),
  activeMinutes: (json['activeMinutes'] as num?)?.toDouble(),
  raw: json['raw'] as Map<String, dynamic>?,
);

Map<String, dynamic> _$FitnessDataToJson(FitnessData instance) =>
    <String, dynamic>{
      'id': instance.id,
      'source': instance.source,
      'date': FitnessData._dateToJson(instance.date),
      'calories': instance.calories,
      'steps': instance.steps,
      'distanceKm': instance.distanceKm,
      'activeMinutes': instance.activeMinutes,
      'raw': instance.raw,
    };
