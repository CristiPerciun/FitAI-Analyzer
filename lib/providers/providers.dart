import 'package:fitai_analyzer/models/meal_model.dart';
import 'package:fitai_analyzer/providers/auth_notifier.dart';
import 'package:fitai_analyzer/services/auth_service.dart';
import 'package:fitai_analyzer/services/nutrition_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Service providers - dependency injection via Riverpod
final authServiceProvider = Provider<AuthService>((ref) => AuthService());

/// Stream dei pasti di oggi, raggruppati per tipo (Colazione/Pranzo/Cena).
/// Ritorna mappa mealLabel -> List di MealModel.
final todayMealsByTypeProvider = StreamProvider<Map<String, List<MealModel>>>((ref) async* {
  final authState = ref.watch(authNotifierProvider);
  final uid = authState.user?.uid;
  if (uid == null) {
    yield {};
    return;
  }
  final dateStr = DateTime.now().toIso8601String().split('T')[0];
  final nutrition = ref.read(nutritionServiceProvider);
  await for (final meals in nutrition.mealsForDayStream(uid, dateStr)) {
    final byType = <String, List<MealModel>>{
      'Colazione': [],
      'Pranzo': [],
      'Cena': [],
    };
    for (final m in meals) {
      final type = m.mealType.isNotEmpty ? m.mealType : _inferMealType(m);
      if (byType.containsKey(type)) {
        byType[type]!.add(m);
      } else {
        byType['Pranzo']!.add(m);
      }
    }
    yield byType;
  }
});

String _inferMealType(MealModel m) {
  final d = m.dishName.toLowerCase();
  if (d.startsWith('colazione')) return 'Colazione';
  if (d.startsWith('pranzo')) return 'Pranzo';
  if (d.startsWith('cena')) return 'Cena';
  return 'Pranzo';
}
