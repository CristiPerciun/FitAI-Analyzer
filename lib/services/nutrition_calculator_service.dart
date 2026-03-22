import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fitai_analyzer/models/user_profile.dart';

/// Calcolo TDEE (Mifflin–St Jeor), fattore attività e target calorico da
/// [NutritionGoal] + dati onboarding in [UserProfile].
class NutritionCalculatorService {
  NutritionCalculatorService._();

  /// BMR Mifflin–St Jeor (kcal/giorno).
  static double bmrMifflinStJeor({
    required double weightKg,
    required double heightCm,
    required int age,
    required String gender,
  }) {
    final isFemale = gender.toLowerCase() == 'female';
    final base = 10 * weightKg + 6.25 * heightCm - 5 * age;
    return isFemale ? base - 161 : base + 5;
  }

  /// Moltiplicatore attività (fattore PAL standard).
  static double activityMultiplierForLevel(String activityLevel) {
    switch (activityLevel.toLowerCase()) {
      case 'sedentary':
      case 'sedentario':
        return 1.2;
      case 'light':
      case 'leggero':
        return 1.375;
      case 'moderate':
      case 'moderato':
        return 1.55;
      case 'active':
      case 'attivo':
        return 1.725;
      case 'very_active':
      case 'molto_attivo':
        return 1.9;
      default:
        return 1.55;
    }
  }

  /// Deriva un livello attività testuale dai giorni di allenamento/settimana (onboarding).
  static String activityLevelFromTrainingDays(int trainingDaysPerWeek) {
    if (trainingDaysPerWeek <= 2) return 'light';
    if (trainingDaysPerWeek == 3) return 'light';
    if (trainingDaysPerWeek == 4) return 'moderate';
    if (trainingDaysPerWeek == 5) return 'active';
    return 'very_active';
  }

  /// TDEE = BMR × fattore attività.
  static double calculateTDEE({
    required double weight,
    required double height,
    required int age,
    required String gender,
    required String activityLevel,
  }) {
    final bmr = bmrMifflinStJeor(
      weightKg: weight,
      heightCm: height,
      age: age,
      gender: gender,
    );
    return bmr * activityMultiplierForLevel(activityLevel);
  }

  /// Frazione di aggiustamento energetico (negativo = deficit, positivo = surplus).
  /// [nutritionObjective] e [speed] da [NutritionGoal.nutritionObjective] (es. `perdita_grasso`, `lenta`).
  static double energyAdjustmentFraction({
    required String nutritionObjective,
    required String speed,
  }) {
    final s = speed.toLowerCase();
    double tier() {
      switch (s) {
        case 'lenta':
          return 0.5;
        case 'aggressiva':
          return 1.0;
        case 'media':
        default:
          return 0.75;
      }
    }

    final t = tier();
    switch (nutritionObjective.toLowerCase()) {
      case 'perdita_grasso':
      case 'dimagrimento':
        return -0.10 + (-0.10 * t); // lenta ~-15%, media ~-17.5%, aggressiva ~-20%
      case 'ipertrofia':
      case 'massa':
        return 0.08 + (0.07 * t); // lenta ~+11.5%, media ~+13.25%, aggressiva ~+15%
      case 'mantenimento':
      case 'maintenance':
        return 0;
      case 'ricomposizione':
        return -0.05 * t; // leggero deficit
      case 'performance':
      case 'prestazione':
        return 0.03 + (0.04 * t);
      default:
        return 0;
    }
  }

  /// Calcolo completo a partire dal profilo onboarding + obiettivo nutrizione.
  static NutritionEnergyResult computeFromUserProfile(UserProfile profile) {
    final ng = profile.nutritionGoal;
    final activityLevel = activityLevelFromTrainingDays(
      profile.trainingDaysPerWeek,
    );
    final bmr = bmrMifflinStJeor(
      weightKg: profile.weightKg,
      heightCm: profile.heightCm,
      age: profile.age,
      gender: profile.gender,
    );
    final mult = activityMultiplierForLevel(activityLevel);
    final tdee = bmr * mult;

    if (ng == null) {
      return NutritionEnergyResult(
        bmrKcal: bmr,
        tdeeKcal: tdee,
        activityLevel: activityLevel,
        activityMultiplier: mult,
        adjustmentFraction: 0,
        calorieTarget: tdee,
      );
    }

    final adj = energyAdjustmentFraction(
      nutritionObjective: ng.nutritionObjective,
      speed: ng.speed,
    );
    final target = (tdee * (1 + adj)).clamp(800.0, 8000.0);

    return NutritionEnergyResult(
      bmrKcal: bmr,
      tdeeKcal: tdee,
      activityLevel: activityLevel,
      activityMultiplier: mult,
      adjustmentFraction: adj,
      calorieTarget: target,
    );
  }

  /// [NutritionGoal] con `calorieTarget` aggiornato dal calcolo (se presente nutritionGoal).
  static UserProfile profileWithComputedCalorieTarget(UserProfile profile) {
    final ng = profile.nutritionGoal;
    if (ng == null) return profile;

    final r = computeFromUserProfile(profile);
    return UserProfile(
      mainGoal: profile.mainGoal,
      age: profile.age,
      gender: profile.gender,
      heightCm: profile.heightCm,
      weightKg: profile.weightKg,
      trainingDaysPerWeek: profile.trainingDaysPerWeek,
      equipment: profile.equipment,
      takesMedications: profile.takesMedications,
      medicationsList: profile.medicationsList,
      healthConditions: profile.healthConditions,
      avgSleepHours: profile.avgSleepHours,
      sleepImportance: profile.sleepImportance,
      trainingGoal: profile.trainingGoal,
      nutritionGoal: ng.copyWith(calorieTarget: r.calorieTarget),
    );
  }

  /// Patch Firestore (merge) per `baseline_profile/main` — campi nutrizione/TDEE.
  static Map<String, dynamic> baselineNutritionPatch(UserProfile profile) {
    final r = computeFromUserProfile(profile);
    final ng = profile.nutritionGoal;
    return {
      'bmr_kcal': r.bmrKcal,
      'tdee_kcal': r.tdeeKcal,
      'activity_multiplier': r.activityMultiplier,
      'activity_level_derived': r.activityLevel,
      'nutrition_calorie_target': r.calorieTarget,
      'nutrition_energy_adjustment_fraction': r.adjustmentFraction,
      if (ng != null) 'nutrition_goal_snapshot': ng.toJson(),
    };
  }

  /// Aggiorna solo i campi nutrizione su `users/{uid}/baseline_profile/main` (merge).
  static Future<void> syncNutritionFieldsToBaseline({
    required FirebaseFirestore firestore,
    required String uid,
    required UserProfile profile,
  }) async {
    if (profile.nutritionGoal == null) return;
    final patch = baselineNutritionPatch(profile);
    await firestore
        .collection('users')
        .doc(uid)
        .collection('baseline_profile')
        .doc('main')
        .set(patch, SetOptions(merge: true));
  }
}

/// Risultato intermedio per baseline e [NutritionGoal.calorieTarget].
class NutritionEnergyResult {
  const NutritionEnergyResult({
    required this.bmrKcal,
    required this.tdeeKcal,
    required this.activityLevel,
    required this.activityMultiplier,
    required this.adjustmentFraction,
    required this.calorieTarget,
  });

  final double bmrKcal;
  final double tdeeKcal;
  final String activityLevel;
  final double activityMultiplier;
  final double adjustmentFraction;
  final double calorieTarget;

  /// Percentuale per prompt / UI (es. -17.5).
  double get adjustmentPercent => adjustmentFraction * 100;
}
