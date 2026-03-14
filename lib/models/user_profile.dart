import 'package:json_annotation/json_annotation.dart';

part 'user_profile.g.dart';

/// Profilo utente per onboarding e personalizzazione piani AI.
/// Valori mainGoal: "weight_loss", "muscle_gain", "longevity", "strength"
@JsonSerializable()
class UserProfile {
  /// Obiettivo principale: "weight_loss", "muscle_gain", "longevity", "strength"
  @JsonKey(name: 'main_goal')
  final String mainGoal;

  final int age;

  /// Genere: "male", "female", "other"
  final String gender;

  @JsonKey(name: 'height_cm')
  final double heightCm;

  @JsonKey(name: 'weight_kg')
  final double weightKg;

  @JsonKey(name: 'training_days_per_week')
  final int trainingDaysPerWeek;

  /// Attrezzatura disponibile: "bodyweight", "home_gym", "full_gym", etc.
  final String equipment;

  @JsonKey(name: 'takes_medications')
  final bool takesMedications;

  @JsonKey(name: 'medications_list')
  final String medicationsList;

  @JsonKey(name: 'health_conditions')
  final String healthConditions;

  @JsonKey(name: 'avg_sleep_hours')
  final double avgSleepHours;

  @JsonKey(name: 'sleep_importance')
  final int sleepImportance;

  const UserProfile({
    required this.mainGoal,
    required this.age,
    required this.gender,
    required this.heightCm,
    required this.weightKg,
    required this.trainingDaysPerWeek,
    required this.equipment,
    required this.takesMedications,
    required this.medicationsList,
    required this.healthConditions,
    required this.avgSleepHours,
    required this.sleepImportance,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) =>
      _$UserProfileFromJson(json);

  Map<String, dynamic> toJson() => _$UserProfileToJson(this);
}
