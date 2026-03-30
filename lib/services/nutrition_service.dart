import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/meal_model.dart';
import '../models/user_profile.dart';
import '../utils/platform_firestore_fix.dart';
import 'ai_prompt_service.dart';
import 'gemini_service.dart';

/// Servizio per salvataggio dati nutrizione (Gemini foto piatto) su Firestore.
/// Strategia a Tre Livelli:
/// - Livello 1: meals subcollection (dettaglio singolo pasto)
/// - Livello 2: nutrition_summary su daily_log (trend settimanale)
/// - Livello 3: baseline_profile usa medie da nutrition_summary
final nutritionServiceProvider = Provider<NutritionService>((ref) {
  return NutritionService(
    aiPromptService: ref.read(aiPromptServiceProvider),
    geminiService: ref.read(geminiServiceProvider),
  );
});

class NutritionService {
  NutritionService({
    required AiPromptService aiPromptService,
    required GeminiService geminiService,
  })  : _aiPromptService = aiPromptService,
        _geminiService = geminiService;

  final AiPromptService _aiPromptService;
  final GeminiService _geminiService;

  /// Salva il pasto nella sottocollezione meals e aggiorna nutrition_summary sul daily_log.
  /// Usa il **NUOVO MealModel** (campi flat proteinG / carbsG / fatG + ingredients + aiConfidence).
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

    // ====================== ESTRAZIONE DATI DA GEMINI ======================
    final dishName = _extractDishName(nutritionGemini, mealLabel);

    final proteinG = _num(nutritionGemini['protein_g'] ?? nutritionGemini['protein'] ?? 0);
    final carbsG = _num(nutritionGemini['carbs_g'] ?? nutritionGemini['carbs'] ?? 0);
    final fatG = _num(nutritionGemini['fat_g'] ?? nutritionGemini['fat'] ?? 0);
    final calories = _num(nutritionGemini['total_calories'] ?? nutritionGemini['calories'] ?? 0);

    final advice = nutritionGemini['advice'] as String? ?? '';
    final longevityScore = _num(nutritionGemini['longevity_score'] ?? 0);

    // Parsing ingredienti (campo già restituito da Gemini)
    final foods = nutritionGemini['foods'] as List<dynamic>? ?? [];
    final ingredients = foods
        .map((f) => (f as Map<String, dynamic>?)?['name'] as String? ?? '')
        .where((name) => name.isNotEmpty)
        .toList();

    final mealType = mealLabel != null
        ? mealLabel.substring(0, 1).toUpperCase() + mealLabel.substring(1)
        : 'Pasto';

    // ====================== NUOVO MEALMODEL ======================
    final meal = MealModel(
      dishName: dishName,
      calories: calories.round(),
      proteinG: proteinG,
      carbsG: carbsG,
      fatG: fatG,
      portionGrams: null, // Gemini non restituisce ancora grammatura totale
      ingredients: ingredients,
      timestamp: timeStr,
      mealType: mealType,
      rawAiAnalysis: advice,
      aiConfidence: 0.85, // default (migliorabile in futuro con score Gemini)
    );

    await firestore.runTransaction((tx) async {
      // 1. Salva pasto nella subcollection (usa il nuovo toFirestore())
      final mealRef = mealsRef.doc();
      tx.set(mealRef, meal.toFirestore());

      // 2. Leggi daily_log corrente per aggregare
      final dailySnap = await tx.get(dailyRef);
      final currentData = dailySnap.data() ?? {};
      final existingSummary = currentData['nutrition_summary'] as Map<String, dynamic>? ?? {};

      // Aggregazione con chiavi nuove (_g) + retro-compatibilità
      final totalKcal = _num(existingSummary['total_kcal'] ?? 0) + calories;
      final totalProtein = _num(existingSummary['total_protein_g'] ?? existingSummary['total_protein'] ?? 0) + proteinG;
      final totalCarbs = _num(existingSummary['total_carbs_g'] ?? existingSummary['total_carbs'] ?? 0) + carbsG;
      final totalFat = _num(existingSummary['total_fat_g'] ?? existingSummary['total_fat'] ?? 0) + fatG;

      final mealsCount = (existingSummary['meals_count'] as int? ?? 0) + 1;

      final longevitySum = _num(existingSummary['_longevity_sum'] ?? 0) +
          (longevityScore > 0 ? longevityScore : 0);
      final longevityCount = (existingSummary['_longevity_count'] as int? ?? 0) +
          (longevityScore > 0 ? 1 : 0);

      final nutritionSummary = <String, dynamic>{
        'total_kcal': totalKcal.round(),
        'total_protein_g': totalProtein.round(),   // ← nuova chiave standard
        'total_carbs_g': totalCarbs.round(),       // ← nuova chiave standard
        'total_fat_g': totalFat.round(),           // ← nuova chiave standard
        'meals_count': mealsCount,
        'avg_longevity_score': longevityCount > 0
            ? (longevitySum / longevityCount).toStringAsFixed(1)
            : null,
        '_longevity_sum': longevitySum,
        '_longevity_count': longevityCount,
      };

      // 3. Aggiorna daily_log
      tx.set(dailyRef, {
        'date': dateStr,
        'nutrition_summary': nutritionSummary,
        'nutrition_gemini': nutritionGemini, // mantenuto per retro-compatibilità
        'timestamp': Timestamp.fromDate(now),
      }, SetOptions(merge: true));
    });
  }

  /// Genera piano settimanale (metodo invariato)
  Future<void> generateInitialMealPlan(String uid) async {
    final firestore = FirebaseFirestore.instance;
    final profileDoc = await firestore
        .collection('users')
        .doc(uid)
        .collection('profile')
        .doc('profile')
        .get();
    if (!profileDoc.exists || profileDoc.data() == null) {
      throw StateError('Profilo non trovato');
    }
    final profile = UserProfile.fromJson(profileDoc.data()!);
    if (profile.nutritionGoal == null) {
      throw StateError('Obiettivo mangiare non configurato');
    }

    final prompt = _aiPromptService.buildNutritionPrompt(profile);
    final plan = await _geminiService.generateFromPrompt(prompt);

    final now = DateTime.now();
    final todayStr = now.toIso8601String().split('T')[0];
    await firestore
        .collection('users')
        .doc(uid)
        .collection('daily_logs')
        .doc(todayStr)
        .set(
      {
        'date': todayStr,
        'weekly_meal_plan': {
          'content': plan,
          'generated_at': Timestamp.fromDate(now),
        },
        'timestamp': Timestamp.fromDate(now),
      },
      SetOptions(merge: true),
    );
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

  double _num(dynamic v) => (v is num) ? v.toDouble() : double.tryParse(v.toString()) ?? 0.0;

  /// Livello 1: Legge i pasti del giorno (ordinati per orario).
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

  /// Stream delle date che hanno almeno un pasto.
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

  /// Stream dei pasti del giorno (real-time).
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