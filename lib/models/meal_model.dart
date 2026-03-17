import 'package:fitai_analyzer/utils/meal_constants.dart';

/// Documento pasto nella sottocollezione meals (Livello 1 - dettaglio).
/// Percorso: /users/{uid}/daily_logs/{date}/meals/{mealId}
///
/// Usato per "Com'è andato il pranzo?" - l'IA legge il dettaglio del singolo piatto.
class MealModel {
  /// Nome del piatto (es. "Pollo e Broccoli").
  final String dishName;

  /// Calorie del piatto.
  final int calories;

  /// Macros: pro, carb, fat (grammi).
  final Map<String, num> macros;

  /// Orario del pasto (es. "12:30").
  final String timestamp;

  /// Tipo pasto: "Colazione", "Pranzo", "Cena".
  final String mealType;

  /// Analisi raw da Gemini (consigli nutrizionali).
  final String rawAiAnalysis;

  const MealModel({
    required this.dishName,
    required this.calories,
    required this.macros,
    required this.timestamp,
    required this.mealType,
    required this.rawAiAnalysis,
  });

  /// Titolo senza prefisso (es. "Pranzo: Pollo" → "Pollo").
  String get displayTitle {
    for (final t in MealConstants.mealTypes) {
      final prefix = '$t: ';
      if (dishName.startsWith(prefix)) {
        return dishName.substring(prefix.length).trim();
      }
    }
    return dishName;
  }

  Map<String, dynamic> toFirestore() => {
        'dish_name': dishName,
        'calories': calories,
        'macros': macros,
        'timestamp': timestamp,
        'meal_type': mealType,
        'raw_ai_analysis': rawAiAnalysis,
      };

  factory MealModel.fromFirestore(Map<String, dynamic> data) {
    final macrosRaw = data['macros'] as Map<String, dynamic>? ?? {};
    final macros = <String, num>{
      'pro': (macrosRaw['pro'] ?? macrosRaw['protein_g'] ?? 0) as num,
      'carb': (macrosRaw['carb'] ?? macrosRaw['carbs_g'] ?? 0) as num,
      'fat': (macrosRaw['fat'] ?? macrosRaw['fat_g'] ?? 0) as num,
    };
    return MealModel(
      dishName: data['dish_name'] as String? ?? 'Piatto',
      calories: (data['calories'] as num?)?.toInt() ?? 0,
      macros: macros,
      timestamp: data['timestamp'] as String? ?? '',
      mealType: data['meal_type'] as String? ?? '',
      rawAiAnalysis: data['raw_ai_analysis'] as String? ?? '',
    );
  }
}
