import 'package:json_annotation/json_annotation.dart';

part 'user_profile.g.dart';

double _toDouble(dynamic v, {double fallback = 0.0}) {
  if (v is num) return v.toDouble();
  if (v == null) return fallback;
  return double.tryParse(v.toString()) ?? fallback;
}

int _toInt(dynamic v, {int fallback = 0}) {
  if (v is num) return v.toInt();
  if (v == null) return fallback;
  return int.tryParse(v.toString()) ?? fallback;
}

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

    // Firestore può contenere numeri come `String` (es. "2000").
    // Per evitare crash nei cast `as num`, facciamo parse robusti.
    return NutritionGoal(
      nutritionObjective: (m['nutrition_objective'] as String?) ?? 'mantenimento',
      calorieTarget: _toDouble(m['calorie_target'], fallback: 0.0),
      proteinGPerKg: _toInt(m['protein_g_per_kg'], fallback: 0),
      carbsPercentage: _toInt(m['carbs_percentage'], fallback: 0),
      fatPercentage: _toInt(m['fat_percentage'], fallback: 0),
      speed: (m['speed'] as String?) ?? 'media',
      mealsPerDay: _toInt(m['meals_per_day'], fallback: 3),
      timingImportante: (m['timing_importante'] as bool?) ?? false,
      style: (m['style'] as String?) ?? 'mediterraneo',
      preferences: (m['preferences'] as List<dynamic>?)
              ?.map((e) => e?.toString() ?? '')
              .where((s) => s.isNotEmpty)
              .toList() ??
          const [],
      useSupplements: (m['use_supplements'] as bool?) ?? false,
      extraNotes: (m['extra_notes'] as String?) ?? '',
    );
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

  // Robustizza i parse: Firestore può salvare numeri come `String`.
  factory UserProfile.fromJson(Map<String, dynamic> json) {
    final m = Map<String, dynamic>.from(json);
    return UserProfile(
      mainGoal: (m['main_goal'] as String?) ?? '',
      age: _toInt(m['age'], fallback: 30),
      gender: (m['gender'] as String?) ?? 'male',
      heightCm: _toDouble(m['height_cm'], fallback: 170),
      weightKg: _toDouble(m['weight_kg'], fallback: 70),
      trainingDaysPerWeek: _toInt(m['training_days_per_week'], fallback: 4),
      equipment: (m['equipment'] as String?) ?? 'full_gym',
      takesMedications: (m['takes_medications'] as bool?) ?? false,
      medicationsList: (m['medications_list'] as String?) ?? '',
      healthConditions: (m['health_conditions'] as String?) ?? '',
      avgSleepHours: _toDouble(m['avg_sleep_hours'], fallback: 7.0),
      sleepImportance: _toInt(m['sleep_importance'], fallback: 3),
      trainingGoal: m['training_goal'] == null
          ? null
          : TrainingGoal.fromJson(
              Map<String, dynamic>.from(m['training_goal'] as Map),
            ),
      nutritionGoal: m['nutrition_goal'] == null
          ? null
          : NutritionGoal.fromJson(
              Map<String, dynamic>.from(m['nutrition_goal'] as Map),
            ),
    );
  }

  Map<String, dynamic> toJson() => _$UserProfileToJson(this);
}
