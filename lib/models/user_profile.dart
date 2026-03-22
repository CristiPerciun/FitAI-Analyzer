import 'package:json_annotation/json_annotation.dart';

part 'user_profile.g.dart';

/// Obiettivo allenamento (ramo separato dal [UserProfile.mainGoal] a 4 vie).
/// Da compilare con onboarding / impostazioni dedicato; struttura pronta per Firestore.
@JsonSerializable()
class TrainingGoal {
  const TrainingGoal({
    this.objectiveKey = '',
    this.notes = '',
  });

  /// Chiave obiettivo training (es. forza, volume, endurance) — allineare a UI futura.
  @JsonKey(name: 'objective_key', defaultValue: '')
  final String objectiveKey;

  @JsonKey(name: 'notes', defaultValue: '')
  final String notes;

  factory TrainingGoal.fromJson(Map<String, dynamic> json) =>
      _$TrainingGoalFromJson(json);

  Map<String, dynamic> toJson() => _$TrainingGoalToJson(this);
}

/// Obiettivo nutrizione (sub-onboarding «Obiettivo Mangiare»).
/// **Non** è il main goal: è il ramo «nutrition» sotto i 4 obiettivi app.
/// [nutritionObjective] es.: `perdita_grasso`, `ipertrofia`, `mantenimento`, …
@JsonSerializable()
class NutritionGoal {
  @JsonKey(name: 'nutrition_objective')
  final String nutritionObjective;

  /// Target calorico giornaliero (valorizzato da [NutritionCalculatorService] al salvataggio).
  @JsonKey(name: 'calorie_target')
  final double calorieTarget;

  /// Proteine g/kg corporeo (es. 2 → ~2.0 g/kg).
  @JsonKey(name: 'protein_g_per_kg')
  final int proteinGPerKg;

  @JsonKey(name: 'carbs_percentage')
  final int carbsPercentage;

  @JsonKey(name: 'fat_percentage')
  final int fatPercentage;

  /// `lenta`, `media`, `aggressiva` — modula deficit/surplus vs TDEE.
  @JsonKey(name: 'speed')
  final String speed;

  @JsonKey(name: 'meals_per_day')
  final int mealsPerDay;

  @JsonKey(name: 'timing_importante')
  final bool timingImportante;

  /// Es. `mediterraneo`, `alto_proteine`.
  @JsonKey(name: 'style')
  final String style;

  @JsonKey(name: 'preferences')
  final List<String> preferences;

  /// Considerare integratori (proteine, creatina, omega-3, ecc.) nei piani AI.
  @JsonKey(name: 'use_supplements', defaultValue: false)
  final bool useSupplements;

  /// Note libere: cosa evitare, preferenze forti, abitudini.
  @JsonKey(name: 'extra_notes', defaultValue: '')
  final String extraNotes;

  const NutritionGoal({
    required this.nutritionObjective,
    required this.calorieTarget,
    required this.proteinGPerKg,
    required this.carbsPercentage,
    required this.fatPercentage,
    required this.speed,
    required this.mealsPerDay,
    required this.timingImportante,
    required this.style,
    this.preferences = const [],
    this.useSupplements = false,
    this.extraNotes = '',
  });

  factory NutritionGoal.fromJson(Map<String, dynamic> json) {
    final m = Map<String, dynamic>.from(json);
    m['nutrition_objective'] = m['nutrition_objective'] ??
        (m['main_goal'] as String?) ??
        'mantenimento';
    return _$NutritionGoalFromJson(m);
  }

  Map<String, dynamic> toJson() => _$NutritionGoalToJson(this);

  /// Valore proteico in g/kg: se [proteinGPerKg] ≥ 10 è in decimi (20 → 2.0), altrimenti intero (2 → 2.0).
  double get proteinGramsPerKg =>
      proteinGPerKg >= 10 ? proteinGPerKg / 10.0 : proteinGPerKg.toDouble();

  NutritionGoal copyWith({
    String? nutritionObjective,
    double? calorieTarget,
    int? proteinGPerKg,
    int? carbsPercentage,
    int? fatPercentage,
    String? speed,
    int? mealsPerDay,
    bool? timingImportante,
    String? style,
    List<String>? preferences,
    bool? useSupplements,
    String? extraNotes,
  }) {
    return NutritionGoal(
      nutritionObjective: nutritionObjective ?? this.nutritionObjective,
      calorieTarget: calorieTarget ?? this.calorieTarget,
      proteinGPerKg: proteinGPerKg ?? this.proteinGPerKg,
      carbsPercentage: carbsPercentage ?? this.carbsPercentage,
      fatPercentage: fatPercentage ?? this.fatPercentage,
      speed: speed ?? this.speed,
      mealsPerDay: mealsPerDay ?? this.mealsPerDay,
      timingImportante: timingImportante ?? this.timingImportante,
      style: style ?? this.style,
      preferences: preferences ?? this.preferences,
      useSupplements: useSupplements ?? this.useSupplements,
      extraNotes: extraNotes ?? this.extraNotes,
    );
  }
}

/// Profilo utente: gerarchia **main goal (4 vie)** → **training goal** → **nutrition goal**.
@JsonSerializable(explicitToJson: true)
class UserProfile {
  /// Obiettivo principale app (sole 4 vie): `weight_loss`, `muscle_gain`, `longevity`, `strength`.
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

  /// Ramo obiettivi allenamento (separato da [mainGoal] e da [nutritionGoal]).
  @JsonKey(name: 'training_goal')
  final TrainingGoal? trainingGoal;

  /// Ramo obiettivi nutrizione (separato da [mainGoal]).
  @JsonKey(name: 'nutrition_goal')
  final NutritionGoal? nutritionGoal;

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
    this.trainingGoal,
    this.nutritionGoal,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) =>
      _$UserProfileFromJson(json);

  Map<String, dynamic> toJson() => _$UserProfileToJson(this);
}
