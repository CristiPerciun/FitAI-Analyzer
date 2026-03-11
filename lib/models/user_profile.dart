import 'package:json_annotation/json_annotation.dart';

// Esegui: dart run build_runner build --delete-conflicting-outputs
// per rigenerare user_profile.g.dart dopo modifiche a questa classe.
part 'user_profile.g.dart';

/// Profilo utente per personalizzazione piani AI (obiettivi, livello, preferenze).
@JsonSerializable()
class UserProfile {
  /// Obiettivo principale: "weight_loss", "muscle_gain", "longevity", "strength"
  final String? mainGoal;

  /// Livello esperienza: 1=principiante, 2=intermedio, 3=avanzato
  final int? experienceLevel;

  final int? age;

  /// Genere: "male", "female", "other"
  final String? gender;

  final double? heightCm;

  final double? weightKg;

  /// Infortuni o condizioni (testo libero)
  final String? injuriesOrConditions;

  /// Giorni di allenamento a settimana (3-7)
  final int? trainingDaysPerWeek;

  /// Attrezzatura disponibile: "bodyweight", "home_gym", "full_gym"
  final String? equipment;

  /// Durata sessione preferita: "short", "medium", "long"
  final String? preferredSessionDuration;

  /// Preferenza dieta: "omnivore", "vegetarian", "vegan", "low_carb"
  final String? dietPreference;

  /// Target specifico (es. "-8kg in 4 mesi", testo libero)
  final String? goalSpecificTarget;

  const UserProfile({
    this.mainGoal,
    this.experienceLevel,
    this.age,
    this.gender,
    this.heightCm,
    this.weightKg,
    this.injuriesOrConditions,
    this.trainingDaysPerWeek,
    this.equipment,
    this.preferredSessionDuration,
    this.dietPreference,
    this.goalSpecificTarget,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) =>
      _$UserProfileFromJson(json);

  Map<String, dynamic> toJson() => _$UserProfileToJson(this);
}
