// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user_profile.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

UserProfile _$UserProfileFromJson(Map<String, dynamic> json) => UserProfile(
  mainGoal: json['main_goal'] as String,
  age: (json['age'] as num).toInt(),
  gender: json['gender'] as String,
  heightCm: (json['height_cm'] as num).toDouble(),
  weightKg: (json['weight_kg'] as num).toDouble(),
  trainingDaysPerWeek: (json['training_days_per_week'] as num).toInt(),
  equipment: json['equipment'] as String,
  takesMedications: json['takes_medications'] as bool,
  medicationsList: json['medications_list'] as String,
  healthConditions: json['health_conditions'] as String,
  avgSleepHours: (json['avg_sleep_hours'] as num).toDouble(),
  sleepImportance: (json['sleep_importance'] as num).toInt(),
);

Map<String, dynamic> _$UserProfileToJson(UserProfile instance) =>
    <String, dynamic>{
      'main_goal': instance.mainGoal,
      'age': instance.age,
      'gender': instance.gender,
      'height_cm': instance.heightCm,
      'weight_kg': instance.weightKg,
      'training_days_per_week': instance.trainingDaysPerWeek,
      'equipment': instance.equipment,
      'takes_medications': instance.takesMedications,
      'medications_list': instance.medicationsList,
      'health_conditions': instance.healthConditions,
      'avg_sleep_hours': instance.avgSleepHours,
      'sleep_importance': instance.sleepImportance,
    };
