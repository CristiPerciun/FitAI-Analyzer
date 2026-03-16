import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/meal_model.dart';
import '../utils/platform_firestore_fix.dart';

/// Servizio per salvataggio dati nutrizione (Gemini foto piatto) su Firestore.
/// Strategia a Tre Livelli:
/// - Livello 1: meals subcollection (dettaglio singolo pasto per "Com'è andato il pranzo?")
/// - Livello 2: nutrition_summary su daily_log (trend settimanale senza scaricare ogni pasto)
/// - Livello 3: baseline_profile usa medie da nutrition_summary
final nutritionServiceProvider = Provider<NutritionService>((ref) => NutritionService());

class NutritionService {
  /// Salva il pasto nella sottocollezione meals e aggiorna nutrition_summary sul daily_log.
  /// [uid] - ID utente Firebase
  /// [nutritionGemini] - Risposta Gemini: dish_name, total_calories, protein_g, carbs_g, fat_g, advice, longevity_score
  /// [mealLabel] - Opzionale: "Colazione", "Pranzo", "Cena" (per arricchire dish_name)
  /// [date] - Data opzionale (default: oggi)
  Future<void> saveToFirestore(
    String uid,
    Map<String, dynamic> nutritionGemini, {
    String? mealLabel,
    DateTime? date,
  }) async {
    final now = DateTime.now();
    final dateStr = (date ?? now).toIso8601String().split('T')[0];
    final timeStr = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

    final firestore = FirebaseFirestore.instance;
    final dailyRef = firestore
        .collection('users')
        .doc(uid)
        .collection('daily_logs')
        .doc(dateStr);
    final mealsRef = dailyRef.collection('meals');

    // Estrai dati da Gemini
    final dishName = _extractDishName(nutritionGemini, mealLabel);
    final pro = _num(nutritionGemini['protein_g'] ?? nutritionGemini['protein'] ?? 0);
    final carb = _num(nutritionGemini['carbs_g'] ?? nutritionGemini['carbs'] ?? 0);
    final fat = _num(nutritionGemini['fat_g'] ?? nutritionGemini['fat'] ?? 0);
    final kcal = _num(nutritionGemini['total_calories'] ?? nutritionGemini['calories'] ?? 0);
    final advice = nutritionGemini['advice'] as String? ?? '';
    final longevityScore = _num(nutritionGemini['longevity_score'] ?? 0);

    final mealType = mealLabel != null
        ? mealLabel.substring(0, 1).toUpperCase() + mealLabel.substring(1)
        : '';
    final meal = MealModel(
      dishName: dishName,
      calories: kcal.round(),
      macros: {'pro': pro, 'carb': carb, 'fat': fat},
      timestamp: timeStr,
      mealType: mealType,
      rawAiAnalysis: advice,
    );

    await firestore.runTransaction((tx) async {
      // 1. Aggiungi pasto in meals subcollection
      final mealRef = mealsRef.doc();
      tx.set(mealRef, meal.toFirestore());

      // 2. Leggi daily_log corrente per aggregare nutrition_summary
      final dailySnap = await tx.get(dailyRef);
      final currentData = dailySnap.data() ?? {};
      final existingSummary = currentData['nutrition_summary'] as Map<String, dynamic>? ?? {};

      final totalKcal = _num(existingSummary['total_kcal'] ?? 0) + kcal;
      final totalProtein = _num(existingSummary['total_protein'] ?? 0) + pro;
      final totalCarbs = _num(existingSummary['total_carbs'] ?? 0) + carb;
      final totalFat = _num(existingSummary['total_fat'] ?? 0) + fat;
      final mealsCount = (existingSummary['meals_count'] as int? ?? 0) + 1;
      final longevitySum = _num(existingSummary['_longevity_sum'] ?? 0) +
          (longevityScore > 0 ? longevityScore : 0);
      final longevityCount = (existingSummary['_longevity_count'] as int? ?? 0) +
          (longevityScore > 0 ? 1 : 0);

      final nutritionSummary = <String, dynamic>{
        'total_kcal': totalKcal.round(),
        'total_protein': totalProtein.round(),
        'total_carbs': totalCarbs.round(),
        'total_fat': totalFat.round(),
        'meals_count': mealsCount,
        'avg_longevity_score': longevityCount > 0
            ? (longevitySum / longevityCount).toStringAsFixed(1)
            : null,
        '_longevity_sum': longevitySum,
        '_longevity_count': longevityCount,
      };

      // 3. Aggiorna daily_log con nutrition_summary + nutrition_gemini (retrocompatibilità)
      tx.set(dailyRef, {
        'date': dateStr,
        'nutrition_summary': nutritionSummary,
        'nutrition_gemini': nutritionGemini,
        'timestamp': Timestamp.fromDate(now),
      }, SetOptions(merge: true));
    });
  }

  String _extractDishName(Map<String, dynamic> nut, String? mealLabel) {
    final prefix = mealLabel != null
        ? mealLabel.substring(0, 1).toUpperCase() + mealLabel.substring(1)
        : null;
    final fromGemini = nut['dish_name'] as String?;
    if (fromGemini != null && fromGemini.isNotEmpty) {
      return prefix != null ? '$prefix: $fromGemini' : fromGemini;
    }
    final foods = nut['foods'] as List<dynamic>? ?? [];
    if (foods.isNotEmpty) {
      final first = foods.first;
      final name = first is Map ? (first['name'] as String? ?? 'Piatto') : 'Piatto';
      return prefix != null ? '$prefix: $name' : name;
    }
    return prefix ?? 'Piatto';
  }

  double _num(dynamic v) => (v is num) ? v.toDouble() : double.tryParse(v.toString()) ?? 0;

  /// Livello 1: Legge i pasti del giorno per domande tipo "Com'è andato il pranzo?".
  /// Ritorna lista di MealModel ordinati per timestamp.
  Future<List<MealModel>> getMealsForDay(String uid, String dateStr) async {
    final snapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('daily_logs')
        .doc(dateStr)
        .collection('meals')
        .orderBy('timestamp')
        .get();

    return snapshot.docs
        .map((d) => MealModel.fromFirestore(d.data()))
        .toList();
  }

  /// Stream delle date (YYYY-MM-DD) che hanno almeno un pasto.
  /// Su Windows usa polling per evitare errori "non-platform thread".
  Stream<List<String>> mealDatesStream(String uid) {
    final query = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('daily_logs');
    return querySnapshotStream(query).map((snap) {
      final dates = snap.docs.map((d) => d.id).toList();
      dates.sort((a, b) => b.compareTo(a));
      return dates;
    });
  }

  /// Stream dei pasti del giorno per aggiornamenti real-time.
  /// Su Windows usa polling per evitare errori "non-platform thread".
  Stream<List<MealModel>> mealsForDayStream(String uid, String dateStr) {
    final query = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('daily_logs')
        .doc(dateStr)
        .collection('meals')
        .orderBy('timestamp');
    return querySnapshotStream(query).map((snapshot) => snapshot.docs
        .map((d) => MealModel.fromFirestore(d.data()))
        .toList());
  }
}
