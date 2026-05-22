import 'package:fitai_analyzer/services/nutrition_ai_json_parser.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('normalizeNutritionAiResult', () {
    test('somma calorie e grammi quando l\'IA elenca più alimenti ma totalizza male', () {
      final raw = {
        'dish_name': 'Tonno e valeriana',
        'total_calories': 55,
        'estimated_portion_grams': 72,
        'protein_g': 12,
        'carbs_g': 0,
        'fat_g': 0,
        'foods': [
          {
            'name': 'Tonno al naturale',
            'calories': 115,
            'portion': '1 scatoletta (80 g)',
            'grams': 80,
            'protein_g': 26,
            'carbs_g': 0,
            'fat_g': 1,
          },
          {
            'name': 'Insalata Valeriana',
            'calories': 20,
            'portion': '100 g',
            'grams': 100,
            'protein_g': 2,
            'carbs_g': 3,
            'fat_g': 0,
          },
        ],
      };

      final out = normalizeNutritionAiResult(raw);

      expect(out['total_calories'], 135);
      expect(out['estimated_portion_grams'], 180);
      expect(out['protein_g'], 28);
      expect(out['carbs_g'], 3);
      expect(out['fat_g'], 1);
    });

    test('scala i macro se mancano quelli per alimento ma le calorie foods sono più alte', () {
      final raw = {
        'total_calories': 50,
        'estimated_portion_grams': 80,
        'protein_g': 10,
        'carbs_g': 2,
        'fat_g': 1,
        'foods': [
          {'name': 'Tonno', 'calories': 100, 'portion': '80 g', 'grams': 80},
        ],
      };

      final out = normalizeNutritionAiResult(raw);

      expect(out['total_calories'], 100);
      expect(out['protein_g'], 20);
      expect(out['carbs_g'], 4);
      expect(out['fat_g'], 2);
    });
  });
}
