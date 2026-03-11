// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user_profile.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

UserProfile _$UserProfileFromJson(Map<String, dynamic> json) => UserProfile(
  mainGoal: json['mainGoal'] as String?,
  experienceLevel: (json['experienceLevel'] as num?)?.toInt(),
  age: (json['age'] as num?)?.toInt(),
  gender: json['gender'] as String?,
  heightCm: (json['heightCm'] as num?)?.toDouble(),
  weightKg: (json['weightKg'] as num?)?.toDouble(),
  injuriesOrConditions: json['injuriesOrConditions'] as String?,
  trainingDaysPerWeek: (json['trainingDaysPerWeek'] as num?)?.toInt(),
  equipment: json['equipment'] as String?,
  preferredSessionDuration: json['preferredSessionDuration'] as String?,
  dietPreference: json['dietPreference'] as String?,
  goalSpecificTarget: json['goalSpecificTarget'] as String?,
);

Map<String, dynamic> _$UserProfileToJson(UserProfile instance) =>
    <String, dynamic>{
      'mainGoal': instance.mainGoal,
      'experienceLevel': instance.experienceLevel,
      'age': instance.age,
      'gender': instance.gender,
      'heightCm': instance.heightCm,
      'weightKg': instance.weightKg,
      'injuriesOrConditions': instance.injuriesOrConditions,
      'trainingDaysPerWeek': instance.trainingDaysPerWeek,
      'equipment': instance.equipment,
      'preferredSessionDuration': instance.preferredSessionDuration,
      'dietPreference': instance.dietPreference,
      'goalSpecificTarget': instance.goalSpecificTarget,
    };
