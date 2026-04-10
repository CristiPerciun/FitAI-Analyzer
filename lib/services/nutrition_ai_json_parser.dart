import 'dart:convert';

/// Parsing risposte JSON nutrizione (Gemini / DeepSeek).
Map<String, dynamic> parseNutritionAiJson(String raw) {
  try {
    final cleaned = raw
        .replaceAll(RegExp(r'```json\s*'), '')
        .replaceAll(RegExp(r'\s*```'), '')
        .trim();
    final decoded = json.decode(cleaned) as Map<String, dynamic>?;
    return decoded ?? {'raw': raw, 'error': 'JSON vuoto'};
  } catch (_) {
    return {'raw': raw, 'error': 'JSON non valido'};
  }
}
