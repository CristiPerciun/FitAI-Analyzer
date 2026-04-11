import 'package:fitai_analyzer/utils/meal_constants.dart';
import 'package:flutter/material.dart';
/// Modello aggiornato per un singolo pasto salvato in Firestore.
/// Ogni pasto arriva già **scomposto** da Gemini con grammi di macro.
/// Struttura standardizzata, chiara e futura-proof per grafici + analisi storica.
class MealModel {
  /// Nome del piatto (es. "Pollo e Broccoli" o "Pranzo: Pollo e Broccoli").
  final String dishName;

  /// Calorie totali del pasto.
  final int calories;

  /// Grammi di proteine.
  final double proteinG;

  /// Grammi di carboidrati.
  final double carbsG;

  /// Grammi di grassi.
  final double fatG;

  /// Grammatura totale del piatto (opzionale, utile per porzioni).
  final double? portionGrams;

  /// Lista ingredienti riconosciuti da Gemini (nuovo campo).
  final List<String> ingredients;

  /// Orario del pasto (es. "12:30").
  final String timestamp;

  /// Tipo pasto: "Colazione", "Pranzo", "Cena", "Spuntino".
  final String mealType;

  /// Analisi raw completa restituita da Gemini (consigli + testo).
  final String rawAiAnalysis;

  /// Livello di confidenza dell'IA (0.0 - 1.0).
  final double aiConfidence;

  /// ID documento `meals/{id}` (solo lato client dopo lettura Firestore).
  final String? firestoreDocumentId;

  /// Miniatura foto piatto (JPEG/PNG) in Base64, opzionale.
  final String? mealThumbBase64;

  const MealModel({
    required this.dishName,
    required this.calories,
    required this.proteinG,
    required this.carbsG,
    required this.fatG,
    this.portionGrams,
    this.ingredients = const [],
    required this.timestamp,
    required this.mealType,
    required this.rawAiAnalysis,
    this.aiConfidence = 0.85,
    this.firestoreDocumentId,
    this.mealThumbBase64,
  });

  /// Titolo pulito senza prefisso (es. "Pranzo: Pollo" → "Pollo").
  /// Mantenuto per compatibilità con UI esistente.
  String get displayTitle {
    for (final t in MealConstants.mealTypes) {
      final prefix = '$t: ';
      if (dishName.startsWith(prefix)) {
        return dishName.substring(prefix.length).trim();
      }
    }
    return dishName;
  }

  /// Getter comodo per grafici e calcoli (chiavi standard).
  Map<String, double> get macros => {
        'protein_g': proteinG,
        'carbs_g': carbsG,
        'fat_g': fatG,
      };

  /// Map per salvare su Firestore (chiavi ESPLICITE e standard).
  Map<String, dynamic> toFirestore() => {
        'dish_name': dishName,
        'calories': calories,
        'protein_g': proteinG,
        'carbs_g': carbsG,
        'fat_g': fatG,
        'portion_grams': portionGrams,
        'ingredients': ingredients,
        'timestamp': timestamp,
        'meal_type': mealType,
        'raw_ai_analysis': rawAiAnalysis,
        'ai_confidence': aiConfidence,
        if (mealThumbBase64 != null && mealThumbBase64!.isNotEmpty)
          'meal_thumb_base64': mealThumbBase64,
      };

  /// Factory da Firestore con **retro-compatibilità completa**.
  /// Legge sia la nuova struttura (campi flat) che la vecchia (Map macros).
  factory MealModel.fromFirestore(Map<String, dynamic> data, {String? documentId}) {
    // Supporto vecchia struttura (macros map)
    final macrosRaw = data['macros'] as Map<String, dynamic>? ?? {};

    final protein = (data['protein_g'] as num? ??
            macrosRaw['pro'] ??
            macrosRaw['protein_g'] ??
            0)
        .toDouble();

    final carbs = (data['carbs_g'] as num? ??
            macrosRaw['carb'] ??
            macrosRaw['carbs_g'] ??
            0)
        .toDouble();

    final fat = (data['fat_g'] as num? ??
            macrosRaw['fat'] ??
            macrosRaw['fat_g'] ??
            0)
        .toDouble();

    final thumb = data['meal_thumb_base64'];
    final fromSnap = documentId?.trim();
    final fromField = data['meal_doc_id']?.toString().trim();
    final resolvedId = (fromSnap != null && fromSnap.isNotEmpty)
        ? fromSnap
        : (fromField != null && fromField.isNotEmpty ? fromField : null);

    return MealModel(
      dishName: data['dish_name'] as String? ?? 'Piatto sconosciuto',
      calories: (data['calories'] as num?)?.toInt() ?? 0,
      proteinG: protein,
      carbsG: carbs,
      fatG: fat,
      portionGrams: (data['portion_grams'] as num?)?.toDouble(),
      ingredients: List<String>.from(data['ingredients'] ?? []),
      timestamp: data['timestamp'] as String? ?? '',
      mealType: data['meal_type'] as String? ?? '',
      rawAiAnalysis: data['raw_ai_analysis'] as String? ?? '',
      aiConfidence: (data['ai_confidence'] as num?)?.toDouble() ?? 0.85,
      firestoreDocumentId: resolvedId,
      mealThumbBase64: thumb is String && thumb.isNotEmpty ? thumb : null,
    );
  }
}

/// Helper per grafici (lasciato invariato perché non riguarda il salvataggio pasto).
class DailyNutrient {
  final String day;
  final double value;

  DailyNutrient(this.day, this.value);
}

/// Helper per obiettivi nutrizionali (lasciato invariato).
class NutrientGoal {
  final String title;
  final String unit;
  final double target;
  final List<DailyNutrient> weeklyData;
  final Color color;

  NutrientGoal({
    required this.title,
    required this.unit,
    required this.target,
    required this.weeklyData,
    required this.color,
  });
}