import 'package:fitai_analyzer/models/user_profile.dart';
import 'package:fitai_analyzer/providers/user_profile_notifier.dart';
import 'package:fitai_analyzer/utils/onboarding_questions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Sentinel per distinguere "non passato" da "passato null" in [copyWith]
/// (necessario per i campi nullable: selezione cancellabile).
const Object _omit = Object();

/// Stato del form profilo principale (onboarding + modifica da Impostazioni).
/// I valori dei `TextField` sono specchiati qui come stringhe grezze così che
/// [buildBase] sia una funzione pura dello stato; i `TextEditingController`
/// restano nel widget per il ciclo di vita.
class MainProfileFormState {
  const MainProfileFormState({
    this.mainGoal,
    this.gender,
    this.trainingDaysPerWeek,
    this.equipment,
    this.dailyActivityLevel,
    this.trainingExperience,
    this.trainingFocus,
    this.ageText = '',
    this.heightText = '',
    this.weightText = '',
    this.targetWeightText = '',
    this.zone2Text = '',
    this.medicationsText = '',
    this.healthConditionsText = '',
    this.takesMedications = false,
    this.avgSleepHours = 7.0,
    this.sleepImportance = 3,
    this.longevityPriorities = const {},
  });

  final String? mainGoal;
  final String? gender;
  final int? trainingDaysPerWeek;
  final String? equipment;
  final String? dailyActivityLevel;
  final String? trainingExperience;
  final String? trainingFocus;
  final String ageText;
  final String heightText;
  final String weightText;
  final String targetWeightText;
  final String zone2Text;
  final String medicationsText;
  final String healthConditionsText;
  final bool takesMedications;
  final double avgSleepHours;
  final int sleepImportance;
  final Set<String> longevityPriorities;

  MainProfileFormState copyWith({
    Object? mainGoal = _omit,
    Object? gender = _omit,
    Object? trainingDaysPerWeek = _omit,
    Object? equipment = _omit,
    Object? dailyActivityLevel = _omit,
    Object? trainingExperience = _omit,
    Object? trainingFocus = _omit,
    String? ageText,
    String? heightText,
    String? weightText,
    String? targetWeightText,
    String? zone2Text,
    String? medicationsText,
    String? healthConditionsText,
    bool? takesMedications,
    double? avgSleepHours,
    int? sleepImportance,
    Set<String>? longevityPriorities,
  }) {
    return MainProfileFormState(
      mainGoal: mainGoal == _omit ? this.mainGoal : mainGoal as String?,
      gender: gender == _omit ? this.gender : gender as String?,
      trainingDaysPerWeek: trainingDaysPerWeek == _omit
          ? this.trainingDaysPerWeek
          : trainingDaysPerWeek as int?,
      equipment: equipment == _omit ? this.equipment : equipment as String?,
      dailyActivityLevel: dailyActivityLevel == _omit
          ? this.dailyActivityLevel
          : dailyActivityLevel as String?,
      trainingExperience: trainingExperience == _omit
          ? this.trainingExperience
          : trainingExperience as String?,
      trainingFocus: trainingFocus == _omit
          ? this.trainingFocus
          : trainingFocus as String?,
      ageText: ageText ?? this.ageText,
      heightText: heightText ?? this.heightText,
      weightText: weightText ?? this.weightText,
      targetWeightText: targetWeightText ?? this.targetWeightText,
      zone2Text: zone2Text ?? this.zone2Text,
      medicationsText: medicationsText ?? this.medicationsText,
      healthConditionsText: healthConditionsText ?? this.healthConditionsText,
      takesMedications: takesMedications ?? this.takesMedications,
      avgSleepHours: avgSleepHours ?? this.avgSleepHours,
      sleepImportance: sleepImportance ?? this.sleepImportance,
      longevityPriorities: longevityPriorities ?? this.longevityPriorities,
    );
  }
}

class MainProfileFormNotifier
    extends AutoDisposeNotifier<MainProfileFormState> {
  @override
  MainProfileFormState build() => const MainProfileFormState();

  void setMainGoal(String? v) => state = state.copyWith(mainGoal: v);
  void setGender(String? v) => state = state.copyWith(gender: v);
  void setTrainingDays(int? v) =>
      state = state.copyWith(trainingDaysPerWeek: v);
  void setEquipment(String? v) => state = state.copyWith(equipment: v);
  void setDailyActivity(String? v) =>
      state = state.copyWith(dailyActivityLevel: v);
  void setTrainingExperience(String? v) =>
      state = state.copyWith(trainingExperience: v);
  void setTrainingFocus(String? v) => state = state.copyWith(trainingFocus: v);
  void setAgeText(String v) => state = state.copyWith(ageText: v);
  void setHeightText(String v) => state = state.copyWith(heightText: v);
  void setWeightText(String v) => state = state.copyWith(weightText: v);
  void setTargetWeightText(String v) =>
      state = state.copyWith(targetWeightText: v);
  void setZone2Text(String v) => state = state.copyWith(zone2Text: v);
  void setMedicationsText(String v) =>
      state = state.copyWith(medicationsText: v);
  void setHealthConditionsText(String v) =>
      state = state.copyWith(healthConditionsText: v);
  void setTakesMedications(bool v) =>
      state = state.copyWith(takesMedications: v);
  void setAvgSleepHours(double v) => state = state.copyWith(avgSleepHours: v);
  void setSleepImportance(int v) => state = state.copyWith(sleepImportance: v);
  void setLongevityPriorities(Set<String> s) =>
      state = state.copyWith(longevityPriorities: {...s});

  /// Pre-popola da un profilo esistente (i `TextEditingController` vengono
  /// inizializzati dal widget leggendo lo stato risultante).
  void seedFrom(UserProfile p) {
    state = MainProfileFormState(
      mainGoal: p.mainGoal,
      gender: p.gender,
      trainingDaysPerWeek: p.trainingDaysPerWeek,
      equipment: p.equipment,
      dailyActivityLevel: p.dailyActivityLevel,
      trainingExperience: p.trainingExperience,
      trainingFocus: p.trainingFocus,
      ageText: p.age.toString(),
      heightText: p.heightCm.toString(),
      weightText: p.weightKg.toString(),
      targetWeightText: p.targetWeightKg?.toString() ?? '',
      zone2Text: p.zone2MinutesTarget?.toString() ?? '',
      medicationsText: p.medicationsList,
      healthConditionsText: p.healthConditions,
      takesMedications: p.takesMedications,
      avgSleepHours: p.avgSleepHours,
      sleepImportance: p.sleepImportance.clamp(1, 5),
      longevityPriorities: {...p.longevityPriorities},
    );
  }

  /// Profilo base costruito dallo stato (campi specifici inclusi solo se
  /// pertinenti all'obiettivo corrente).
  UserProfile buildBase() {
    final s = state;
    final vis = visibilityForGoal(s.mainGoal);
    return UserProfile(
      mainGoal: s.mainGoal ?? 'longevity',
      age: int.tryParse(s.ageText.trim()) ?? 30,
      gender: s.gender ?? 'male',
      heightCm: double.tryParse(s.heightText.trim()) ?? 170,
      weightKg: double.tryParse(s.weightText.trim()) ?? 70,
      trainingDaysPerWeek: s.trainingDaysPerWeek ?? 4,
      equipment: s.equipment ?? 'full_gym',
      takesMedications: s.takesMedications,
      medicationsList: s.medicationsText.trim(),
      healthConditions: s.healthConditionsText.trim(),
      avgSleepHours: s.avgSleepHours,
      sleepImportance: s.sleepImportance,
      dailyActivityLevel: s.dailyActivityLevel,
      targetWeightKg: vis.showTargetWeight
          ? double.tryParse(s.targetWeightText.trim())
          : null,
      trainingExperience: vis.showTrainingExperience
          ? s.trainingExperience
          : null,
      trainingFocus: vis.showTrainingExperience ? s.trainingFocus : null,
      zone2MinutesTarget: vis.showLongevityPriorities
          ? int.tryParse(s.zone2Text.trim())
          : null,
      longevityPriorities: vis.showLongevityPriorities
          ? s.longevityPriorities.toList()
          : const [],
    );
  }

  /// Profilo principale + conserva ramo nutrizione e training dal profilo corrente.
  UserProfile buildMergedProfile() {
    final cur = ref.read(userProfileNotifierProvider).profile;
    return buildBase().copyWith(
      nutritionGoal: cur?.nutritionGoal,
      trainingGoal: cur?.trainingGoal,
    );
  }

  void clear() => state = const MainProfileFormState();
}

final mainProfileFormProvider =
    AutoDisposeNotifierProvider<MainProfileFormNotifier, MainProfileFormState>(
      MainProfileFormNotifier.new,
    );
