/// Documento pasto nella sottocollezione meals (Livello 1 - dettaglio).
/// Percorso: /users/{uid}/daily_logs/{date}/meals/{mealId}
///
/// Usato per "Com'è andato il pranzo?" - l'IA legge il dettaglio del singolo piatto.
class MealModel {
  /// Nome del piatto (es. "Pollo e Broccoli").
  final String dishName;

  /// Macros: pro, carb, fat (grammi).
  final Map<String, num> macros;

  /// Orario del pasto (es. "12:30").
  final String timestamp;

  /// Analisi raw da Gemini (consigli nutrizionali).
  final String rawAiAnalysis;

  const MealModel({
    required this.dishName,
    required this.macros,
    required this.timestamp,
    required this.rawAiAnalysis,
  });

  Map<String, dynamic> toFirestore() => {
        'dish_name': dishName,
        'macros': macros,
        'timestamp': timestamp,
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
      macros: macros,
      timestamp: data['timestamp'] as String? ?? '',
      rawAiAnalysis: data['raw_ai_analysis'] as String? ?? '',
    );
  }
}
