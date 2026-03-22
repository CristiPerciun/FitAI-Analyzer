// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user_profile.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

TrainingGoal _$TrainingGoalFromJson(Map<String, dynamic> json) => TrainingGoal(
  objectiveKey: json['objective_key'] as String? ?? '',
  notes: json['notes'] as String? ?? '',
);

Map<String, dynamic> _$TrainingGoalToJson(TrainingGoal instance) =>
    <String, dynamic>{
      'objective_key': instance.objectiveKey,
      'notes': instance.notes,
    };

NutritionGoal _$NutritionGoalFromJson(Map<String, dynamic> json) =>
    NutritionGoal(
      nutritionObjective: json['nutrition_objective'] as String,
      calorieTarget: (json['calorie_target'] as num).toDouble(),
      proteinGPerKg: (json['protein_g_per_kg'] as num).toInt(),
      carbsPercentage: (json['carbs_percentage'] as num).toInt(),
      fatPercentage: (json['fat_percentage'] as num).toInt(),
      speed: json['speed'] as String,
      mealsPerDay: (json['meals_per_day'] as num).toInt(),
      timingImportante: json['timing_importante'] as bool,
      style: json['style'] as String,
      preferences:
          (json['preferences'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      useSupplements: json['use_supplements'] as bool? ?? false,
      extraNotes: json['extra_notes'] as String? ?? '',
    );

Map<String, dynamic> _$NutritionGoalToJson(NutritionGoal instance) =>
    <String, dynamic>{
      'nutrition_objective': instance.nutritionObjective,
      'calorie_target': instance.calorieTarget,
      'protein_g_per_kg': instance.proteinGPerKg,
      'carbs_percentage': instance.carbsPercentage,
      'fat_percentage': instance.fatPercentage,
      'speed': instance.speed,
      'meals_per_day': instance.mealsPerDay,
      'timing_importante': instance.timingImportante,
      'style': instance.style,
      'preferences': instance.preferences,
      'use_supplements': instance.useSupplements,
      'extra_notes': instance.extraNotes,
    };

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
  trainingGoal: json['training_goal'] == null
      ? null
      : TrainingGoal.fromJson(json['training_goal'] as Map<String, dynamic>),
  nutritionGoal: json['nutrition_goal'] == null
      ? null
      : NutritionGoal.fromJson(json['nutrition_goal'] as Map<String, dynamic>),
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
      'training_goal': instance.trainingGoal?.toJson(),
      'nutrition_goal': instance.nutritionGoal?.toJson(),
    };
