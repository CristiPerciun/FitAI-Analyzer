import 'dart:convert';

/// Parsing risposte JSON nutrizione (Gemini / DeepSeek / OpenRouter).
Map<String, dynamic> parseNutritionAiJson(String raw) {
  try {
    final cleaned = raw
        .replaceAll(RegExp(r'```json\s*'), '')
        .replaceAll(RegExp(r'\s*```'), '')
        .trim();
    final decoded = json.decode(cleaned) as Map<String, dynamic>?;
    if (decoded == null) return {'raw': raw, 'error': 'JSON vuoto'};
    return normalizeNutritionAiResult(decoded);
  } catch (_) {
    return {'raw': raw, 'error': 'JSON non valido'};
  }
}

/// Corregge totali incoerenti quando l'IA elenca più alimenti ma somma male macro/porzione.
Map<String, dynamic> normalizeNutritionAiResult(Map<String, dynamic> raw) {
  final m = Map<String, dynamic>.from(raw);
  if (m.containsKey('error')) return m;

  final foods = m['foods'];
  if (foods is! List || foods.isEmpty) return m;

  var sumCalories = 0.0;
  var sumProtein = 0.0;
  var sumCarbs = 0.0;
  var sumFat = 0.0;
  var sumGrams = 0.0;
  var hasItemMacros = false;

  for (final item in foods) {
    if (item is! Map) continue;
    sumCalories += _num(item['calories']);

    final grams = _itemGrams(item);
    if (grams > 0) sumGrams += grams;

    if (_hasMacroFields(item)) {
      hasItemMacros = true;
      sumProtein += _num(item['protein_g'] ?? item['protein']);
      sumCarbs += _num(item['carbs_g'] ?? item['carbs']);
      sumFat += _num(item['fat_g'] ?? item['fat']);
    }
  }

  final totalCalories = _num(m['total_calories'] ?? m['calories']);
  if (sumCalories > 0 && (totalCalories <= 0 || sumCalories > totalCalories * 1.1)) {
    final ratio = totalCalories > 0 ? sumCalories / totalCalories : 1.0;
    final roundedCalories = sumCalories.round();
    m['total_calories'] = roundedCalories;
    m['calories'] = roundedCalories;

    if (hasItemMacros) {
      m['protein_g'] = sumProtein.round();
      m['carbs_g'] = sumCarbs.round();
      m['fat_g'] = sumFat.round();
    } else if (totalCalories > 0 && ratio > 1.1) {
      m['protein_g'] = (_num(m['protein_g'] ?? m['protein']) * ratio).round();
      m['carbs_g'] = (_num(m['carbs_g'] ?? m['carbs']) * ratio).round();
      m['fat_g'] = (_num(m['fat_g'] ?? m['fat']) * ratio).round();
      m['sugar_g'] = (_num(m['sugar_g'] ?? m['sugar']) * ratio).round();
    }
  } else if (hasItemMacros) {
    final currentProtein = _num(m['protein_g'] ?? m['protein']);
    final currentCarbs = _num(m['carbs_g'] ?? m['carbs']);
    final currentFat = _num(m['fat_g'] ?? m['fat']);
    if (sumProtein > currentProtein * 1.1) m['protein_g'] = sumProtein.round();
    if (sumCarbs > currentCarbs * 1.1) m['carbs_g'] = sumCarbs.round();
    if (sumFat > currentFat * 1.1) m['fat_g'] = sumFat.round();
  }

  final portionGrams = _num(
    m['estimated_portion_grams'] ?? m['portion_grams'] ?? m['portion_g'],
  );
  if (sumGrams > 0 && (portionGrams <= 0 || sumGrams > portionGrams * 1.1)) {
    final roundedGrams = sumGrams.round();
    m['estimated_portion_grams'] = roundedGrams;
    m['portion_grams'] = roundedGrams;
  }

  return m;
}

double _itemGrams(Map item) {
  final grams = _num(item['grams'] ?? item['portion_grams'] ?? item['portion_g']);
  if (grams > 0) return grams;
  return _parseGramsFromPortion(item['portion']);
}

bool _hasMacroFields(Map item) =>
    item.containsKey('protein_g') ||
    item.containsKey('protein') ||
    item.containsKey('carbs_g') ||
    item.containsKey('carbs') ||
    item.containsKey('fat_g') ||
    item.containsKey('fat');

double _num(dynamic value) {
  if (value == null) return 0;
  if (value is num) return value.toDouble();
  if (value is String) {
    return double.tryParse(value.replaceAll(',', '.').trim()) ?? 0;
  }
  return 0;
}

/// Estrae grammi da stringhe tipo "80 g", "1 scatoletta (80g)".
double _parseGramsFromPortion(dynamic portion) {
  if (portion == null) return 0;
  final text = portion.toString().toLowerCase();
  final match = RegExp(r'(\d+(?:[.,]\d+)?)\s*g\b').firstMatch(text);
  if (match != null) {
    return double.tryParse(match.group(1)!.replaceAll(',', '.')) ?? 0;
  }
  return 0;
}
