import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Stato editabile del dialog pasto (foto o testo Gemini) prima del salvataggio su Firestore.
class NutritionMealEditState {
  const NutritionMealEditState({
    required this.sourceMap,
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
    required this.sugar,
  });

  /// Copia della mappa Gemini originale; [toModifiedNut] la aggiorna con i macro editati.
  final Map<String, dynamic> sourceMap;
  final int calories;
  final int protein;
  final int carbs;
  final int fat;
  final int sugar;

  static int safeInt(dynamic value) {
    if (value == null) return 0;
    if (value is num) return value.toInt();
    if (value is String) return double.tryParse(value)?.toInt() ?? 0;
    return 0;
  }

  Map<String, dynamic> toModifiedNut() {
    final m = Map<String, dynamic>.from(sourceMap);
    m['total_calories'] = calories;
    m['protein_g'] = protein;
    m['carbs_g'] = carbs;
    m['fat_g'] = fat;
    m['sugar_g'] = sugar;
    return m;
  }

  NutritionMealEditState copyWith({
    Map<String, dynamic>? sourceMap,
    int? calories,
    int? protein,
    int? carbs,
    int? fat,
    int? sugar,
  }) {
    return NutritionMealEditState(
      sourceMap: sourceMap ?? this.sourceMap,
      calories: calories ?? this.calories,
      protein: protein ?? this.protein,
      carbs: carbs ?? this.carbs,
      fat: fat ?? this.fat,
      sugar: sugar ?? this.sugar,
    );
  }
}

class NutritionMealEditNotifier extends Notifier<NutritionMealEditState?> {
  @override
  NutritionMealEditState? build() => null;

  void beginFrom(Map<String, dynamic> initialNut) {
    final n = Map<String, dynamic>.from(initialNut);
    state = NutritionMealEditState(
      sourceMap: n,
      calories: NutritionMealEditState.safeInt(n['total_calories'] ?? n['calories']),
      protein: NutritionMealEditState.safeInt(n['protein_g'] ?? n['protein']),
      carbs: NutritionMealEditState.safeInt(n['carbs_g'] ?? n['carbs']),
      fat: NutritionMealEditState.safeInt(n['fat_g'] ?? n['fat']),
      sugar: NutritionMealEditState.safeInt(n['sugar_g'] ?? n['sugar']),
    );
  }

  void setCalories(int v) =>
      state = state?.copyWith(calories: v.clamp(0, 9999));

  void setProtein(int v) => state = state?.copyWith(protein: v.clamp(0, 999));

  void setCarbs(int v) => state = state?.copyWith(carbs: v.clamp(0, 999));

  void setFat(int v) => state = state?.copyWith(fat: v.clamp(0, 999));

  void setSugar(int v) => state = state?.copyWith(sugar: v.clamp(0, 999));

  void clear() => state = null;
}

final nutritionMealEditProvider =
    NotifierProvider<NutritionMealEditNotifier, NutritionMealEditState?>(
  NutritionMealEditNotifier.new,
);
