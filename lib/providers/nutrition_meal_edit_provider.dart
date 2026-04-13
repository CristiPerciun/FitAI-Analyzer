import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Stato editabile prima del salvataggio su Firestore.
/// La **porzione (g)** è la leva principale: calorie e macro scalano in proporzione rispetto ai valori baseline dell’IA.
class NutritionMealEditState {
  const NutritionMealEditState({
    required this.sourceMap,
    required this.basePortionGrams,
    required this.portionGrams,
    required this.baseCalories,
    required this.baseProtein,
    required this.baseCarbs,
    required this.baseFat,
    required this.baseSugar,
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
    required this.sugar,
  });

  final Map<String, dynamic> sourceMap;

  /// Grammatura di riferimento a cui corrispondono i valori baseline (stima IA).
  final double basePortionGrams;

  /// Porzione corrente scelta dall’utente (g).
  final int portionGrams;

  final int baseCalories;
  final int baseProtein;
  final int baseCarbs;
  final int baseFat;
  final int baseSugar;

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

  /// Estrae la porzione stimata dall’output IA; default 300 g se assente.
  static double parseBasePortionGrams(Map<String, dynamic> n) {
    const keys = [
      'estimated_portion_grams',
      'portion_grams',
      'portion_g',
      'total_portion_grams',
    ];
    for (final key in keys) {
      final v = n[key];
      if (v is num && v > 0) return v.toDouble();
      if (v is String) {
        final p = double.tryParse(v.replaceAll(',', '.').trim());
        if (p != null && p > 0) return p;
      }
    }
    return 300.0;
  }

  Map<String, dynamic> toModifiedNut() {
    final m = Map<String, dynamic>.from(sourceMap);
    m['total_calories'] = calories;
    m['calories'] = calories;
    m['protein_g'] = protein;
    m['carbs_g'] = carbs;
    m['fat_g'] = fat;
    m['sugar_g'] = sugar;
    m['portion_grams'] = portionGrams;
    m['estimated_portion_grams'] = portionGrams;
    return m;
  }

  NutritionMealEditState copyWith({
    Map<String, dynamic>? sourceMap,
    double? basePortionGrams,
    int? portionGrams,
    int? baseCalories,
    int? baseProtein,
    int? baseCarbs,
    int? baseFat,
    int? baseSugar,
    int? calories,
    int? protein,
    int? carbs,
    int? fat,
    int? sugar,
  }) {
    return NutritionMealEditState(
      sourceMap: sourceMap ?? this.sourceMap,
      basePortionGrams: basePortionGrams ?? this.basePortionGrams,
      portionGrams: portionGrams ?? this.portionGrams,
      baseCalories: baseCalories ?? this.baseCalories,
      baseProtein: baseProtein ?? this.baseProtein,
      baseCarbs: baseCarbs ?? this.baseCarbs,
      baseFat: baseFat ?? this.baseFat,
      baseSugar: baseSugar ?? this.baseSugar,
      calories: calories ?? this.calories,
      protein: protein ?? this.protein,
      carbs: carbs ?? this.carbs,
      fat: fat ?? this.fat,
      sugar: sugar ?? this.sugar,
    );
  }
}

class NutritionMealEditNotifier extends Notifier<NutritionMealEditState?> {
  static const int _portionMin = 20;
  static const int _portionMax = 2000;

  @override
  NutritionMealEditState? build() => null;

  void beginFrom(Map<String, dynamic> initialNut) {
    final n = Map<String, dynamic>.from(initialNut);
    final basePortion = NutritionMealEditState.parseBasePortionGrams(n).clamp(1.0, 5000.0);
    final bc = NutritionMealEditState.safeInt(n['total_calories'] ?? n['calories']);
    final bp = NutritionMealEditState.safeInt(n['protein_g'] ?? n['protein']);
    final bcar = NutritionMealEditState.safeInt(n['carbs_g'] ?? n['carbs']);
    final bf = NutritionMealEditState.safeInt(n['fat_g'] ?? n['fat']);
    final bs = NutritionMealEditState.safeInt(n['sugar_g'] ?? n['sugar']);

    final startPortion = basePortion.round().clamp(_portionMin, _portionMax);

    state = NutritionMealEditState(
      sourceMap: n,
      basePortionGrams: basePortion,
      portionGrams: startPortion,
      baseCalories: bc,
      baseProtein: bp,
      baseCarbs: bcar,
      baseFat: bf,
      baseSugar: bs,
      calories: bc,
      protein: bp,
      carbs: bcar,
      fat: bf,
      sugar: bs,
    );

    _rescaleToPortion(startPortion);
  }

  void _rescaleToPortion(int portionGrams) {
    final s = state;
    if (s == null) return;
    final p = portionGrams.clamp(_portionMin, _portionMax);
    final factor = p / s.basePortionGrams;

    state = s.copyWith(
      portionGrams: p,
      calories: (s.baseCalories * factor).round().clamp(0, 99999),
      protein: (s.baseProtein * factor).round().clamp(0, 9999),
      carbs: (s.baseCarbs * factor).round().clamp(0, 9999),
      fat: (s.baseFat * factor).round().clamp(0, 9999),
      sugar: (s.baseSugar * factor).round().clamp(0, 9999),
    );
  }

  /// Step consigliato (g) per i pulsanti +/−.
  void adjustPortionBy(int deltaGrams) {
    final s = state;
    if (s == null) return;
    _rescaleToPortion(s.portionGrams + deltaGrams);
  }

  void setPortionGrams(int grams) => _rescaleToPortion(grams);

  void clear() => state = null;
}

final nutritionMealEditProvider =
    NotifierProvider<NutritionMealEditNotifier, NutritionMealEditState?>(
  NutritionMealEditNotifier.new,
);
