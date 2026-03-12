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
  activityType: json['activityType'] as String?,
  activityName: json['activityName'] as String?,
  deviceName: json['deviceName'] as String?,
  elevationGainM: (json['elevationGainM'] as num?)?.toDouble(),
  avgHeartrate: (json['avgHeartrate'] as num?)?.toDouble(),
  maxHeartrate: (json['maxHeartrate'] as num?)?.toDouble(),
  avgSpeedKmh: (json['avgSpeedKmh'] as num?)?.toDouble(),
  elapsedMinutes: (json['elapsedMinutes'] as num?)?.toDouble(),
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
      'activityType': instance.activityType,
      'activityName': instance.activityName,
      'deviceName': instance.deviceName,
      'elevationGainM': instance.elevationGainM,
      'avgHeartrate': instance.avgHeartrate,
      'maxHeartrate': instance.maxHeartrate,
      'avgSpeedKmh': instance.avgSpeedKmh,
      'elapsedMinutes': instance.elapsedMinutes,
    };
