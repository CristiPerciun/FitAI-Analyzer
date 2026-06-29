import 'package:fitai_analyzer/models/user_profile.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Mappa i 4 [UserProfile.mainGoal] → pre-selezione [NutritionGoal.nutritionObjective].
String mapAppMainToNutritionObjective(String mainGoal) {
  switch (mainGoal) {
    case 'weight_loss':
      return 'perdita_grasso';
    case 'muscle_gain':
      return 'ipertrofia';
    case 'strength':
      return 'performance';
    case 'longevity':
    default:
      return 'mantenimento';
  }
}

const _validObjectiveKeys = <String>{
  'perdita_grasso',
  'ipertrofia',
  'mantenimento',
  'ricomposizione',
  'performance',
};

/// Stato del form "Obiettivo mangiare" (NutritionGoalScreen). Le stringhe libere
/// (note) sono specchiate qui; il `TextEditingController` resta nel widget.
class NutritionGoalFormState {
  const NutritionGoalFormState({
    this.mealsPerDay = 3,
    this.timingImportante = false,
    this.fuoriCasa = const {},
    this.allergie = const {},
    this.esclusioni = const {},
    this.nutritionObjective = 'mantenimento',
    this.speed = 'media',
    this.styleKey = 'mediterraneo',
    this.proteinLevel = 'standard',
    this.carbStyle = 'equilibrato',
    this.useSupplements = false,
    this.extraNotesText = '',
  });

  final double mealsPerDay;
  final bool timingImportante;
  final Set<String> fuoriCasa;
  final Set<String> allergie;
  final Set<String> esclusioni;
  final String nutritionObjective;
  final String speed;
  final String styleKey;
  final String proteinLevel;
  final String carbStyle;
  final bool useSupplements;
  final String extraNotesText;

  NutritionGoalFormState copyWith({
    double? mealsPerDay,
    bool? timingImportante,
    Set<String>? fuoriCasa,
    Set<String>? allergie,
    Set<String>? esclusioni,
    String? nutritionObjective,
    String? speed,
    String? styleKey,
    String? proteinLevel,
    String? carbStyle,
    bool? useSupplements,
    String? extraNotesText,
  }) {
    return NutritionGoalFormState(
      mealsPerDay: mealsPerDay ?? this.mealsPerDay,
      timingImportante: timingImportante ?? this.timingImportante,
      fuoriCasa: fuoriCasa ?? this.fuoriCasa,
      allergie: allergie ?? this.allergie,
      esclusioni: esclusioni ?? this.esclusioni,
      nutritionObjective: nutritionObjective ?? this.nutritionObjective,
      speed: speed ?? this.speed,
      styleKey: styleKey ?? this.styleKey,
      proteinLevel: proteinLevel ?? this.proteinLevel,
      carbStyle: carbStyle ?? this.carbStyle,
      useSupplements: useSupplements ?? this.useSupplements,
      extraNotesText: extraNotesText ?? this.extraNotesText,
    );
  }
}

class NutritionGoalFormNotifier
    extends AutoDisposeNotifier<NutritionGoalFormState> {
  @override
  NutritionGoalFormState build() => const NutritionGoalFormState();

  void setMealsPerDay(double v) => state = state.copyWith(mealsPerDay: v);
  void setTimingImportante(bool v) =>
      state = state.copyWith(timingImportante: v);
  void setFuoriCasa(Set<String> s) => state = state.copyWith(fuoriCasa: {...s});
  void setAllergie(Set<String> s) => state = state.copyWith(allergie: {...s});
  void setEsclusioni(Set<String> s) =>
      state = state.copyWith(esclusioni: {...s});
  void setNutritionObjective(String v) =>
      state = state.copyWith(nutritionObjective: v);
  void setSpeed(String v) => state = state.copyWith(speed: v);
  void setStyleKey(String v) => state = state.copyWith(styleKey: v);
  void setProteinLevel(String v) => state = state.copyWith(proteinLevel: v);
  void setCarbStyle(String v) => state = state.copyWith(carbStyle: v);
  void setUseSupplements(bool v) => state = state.copyWith(useSupplements: v);
  void setExtraNotesText(String v) => state = state.copyWith(extraNotesText: v);

  /// Pre-popola dal profilo (obiettivo nutrizione esistente o default da main goal).
  void seedFrom(UserProfile p) {
    final existing = p.nutritionGoal;
    if (existing != null) {
      final fuori = existing.preferences
          .where((e) => e.startsWith('fuori:'))
          .map((e) => e.split(':').last)
          .toSet();
      final allergie = existing.preferences
          .where((e) => e.startsWith('allergia:'))
          .map((e) => e.split(':').last)
          .toSet();
      final esclusioni = existing.preferences
          .where((e) => e.startsWith('escludi:'))
          .map((e) => e.split(':').last)
          .toSet();
      state = NutritionGoalFormState(
        nutritionObjective: existing.nutritionObjective,
        speed: existing.speed,
        styleKey: existing.style,
        mealsPerDay: existing.mealsPerDay.toDouble(),
        timingImportante: existing.timingImportante,
        proteinLevel: _proteinLevelFromGrams(existing.proteinGramsPerKg),
        carbStyle: _carbStyleFromPercent(existing.carbsPercentage),
        useSupplements: existing.useSupplements,
        extraNotesText: existing.extraNotes,
        fuoriCasa: fuori,
        allergie: allergie,
        esclusioni: esclusioni,
      );
    } else {
      state = state.copyWith(
        nutritionObjective: mapAppMainToNutritionObjective(p.mainGoal),
      );
    }
  }

  static String _proteinLevelFromGrams(double g) {
    const tiers = [1.6, 1.8, 2.0, 2.2];
    const keys = ['leggero', 'standard', 'allenamento', 'massa'];
    var best = 0;
    for (var i = 1; i < 4; i++) {
      if ((g - tiers[i]).abs() < (g - tiers[best]).abs()) best = i;
    }
    return keys[best];
  }

  static String _carbStyleFromPercent(int carbs) {
    if (carbs >= 48) return 'piu_carb';
    if (carbs <= 40) return 'meno_carb';
    return 'equilibrato';
  }

  /// Decimi g/kg (16–22) dal livello scelto.
  int get _proteinDeciFromLevel {
    switch (state.proteinLevel) {
      case 'leggero':
        return 16;
      case 'allenamento':
        return 20;
      case 'massa':
        return 22;
      case 'standard':
      default:
        return 18;
    }
  }

  /// (carbs %, fat %) indicativi per AI / modello.
  (int carbs, int fat) get _macroSplitFromCarbStyle {
    switch (state.carbStyle) {
      case 'piu_carb':
        return (50, 28);
      case 'meno_carb':
        return (38, 37);
      case 'equilibrato':
      default:
        return (45, 32);
    }
  }

  /// Costruisce il modello senza salvare (es. salvataggio combinato da Impostazioni).
  NutritionGoal buildModel() {
    final s = state;
    final prefs = <String>[
      ...s.fuoriCasa.map((e) => 'fuori:$e'),
      ...s.allergie.map((e) => 'allergia:$e'),
      ...s.esclusioni.map((e) => 'escludi:$e'),
    ];
    final macro = _macroSplitFromCarbStyle;
    return NutritionGoal(
      nutritionObjective: s.nutritionObjective,
      calorieTarget: 0,
      proteinGPerKg: _proteinDeciFromLevel,
      carbsPercentage: macro.$1,
      fatPercentage: macro.$2,
      speed: s.speed,
      mealsPerDay: s.mealsPerDay.round().clamp(2, 6),
      timingImportante: s.timingImportante,
      style: s.styleKey,
      preferences: prefs,
      useSupplements: s.useSupplements,
      extraNotes: s.extraNotesText.trim(),
    );
  }

  /// True se l'obiettivo nutrizionale selezionato è valido.
  bool validateObjective() =>
      _validObjectiveKeys.contains(state.nutritionObjective);

  void clear() => state = const NutritionGoalFormState();
}

final nutritionGoalFormProvider =
    AutoDisposeNotifierProvider<
      NutritionGoalFormNotifier,
      NutritionGoalFormState
    >(NutritionGoalFormNotifier.new);
