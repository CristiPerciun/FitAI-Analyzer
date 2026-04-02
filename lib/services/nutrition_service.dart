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

    final advice = _stringField(nutritionGemini['advice']);
    final longevityScore = _num(nutritionGemini['longevity_score'] ?? 0);

    // Parsing ingredienti (senza cast che possano fallire su JSON eterogeneo)
    final ingredients = _ingredientNamesFromFoods(nutritionGemini['foods']);

    final mealType = (mealLabel != null && mealLabel.isNotEmpty)
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

    // Lettura + batch (no runTransaction): su Windows il client Firestore C++ va spesso
    // in abort() con le transazioni; iOS/Android reggono meglio ma il batch è equivalente
    // per questo flusso (piccola race se due salvataggi simultanei sullo stesso giorno).
    final dailySnap = await dailyRef.get();
    final currentData = dailySnap.data() ?? {};
    final rawSummary = currentData['nutrition_summary'];
    final existingSummary = rawSummary is Map
        ? Map<String, dynamic>.from(rawSummary)
        : <String, dynamic>{};

    final totalKcal = _num(existingSummary['total_kcal'] ?? 0) + calories;
    final totalProtein =
        _num(existingSummary['total_protein_g'] ?? existingSummary['total_protein'] ?? 0) + proteinG;
    final totalCarbs =
        _num(existingSummary['total_carbs_g'] ?? existingSummary['total_carbs'] ?? 0) + carbsG;
    final totalFat =
        _num(existingSummary['total_fat_g'] ?? existingSummary['total_fat'] ?? 0) + fatG;

    final mealsCount = _intFromFirestore(existingSummary['meals_count']) + 1;

    final longevitySum = _num(existingSummary['_longevity_sum'] ?? 0) +
        (longevityScore > 0 ? longevityScore : 0);
    final longevityCount = _intFromFirestore(existingSummary['_longevity_count']) +
        (longevityScore > 0 ? 1 : 0);

    final nutritionSummary = <String, dynamic>{
      'total_kcal': totalKcal.round(),
      'total_protein_g': totalProtein.round(),
      'total_carbs_g': totalCarbs.round(),
      'total_fat_g': totalFat.round(),
      'meals_count': mealsCount,
      'avg_longevity_score': longevityCount > 0
          ? (longevitySum / longevityCount).toStringAsFixed(1)
          : null,
      '_longevity_sum': longevitySum,
      '_longevity_count': longevityCount,
    };

    final sanitizedGemini =
        _sanitizeForFirestoreMap(Map<String, dynamic>.from(nutritionGemini));

    final mealRef = mealsRef.doc();
    final batch = firestore.batch();
    batch.set(mealRef, meal.toFirestore());
    batch.set(
      dailyRef,
      {
        'date': dateStr,
        'nutrition_summary': nutritionSummary,
        'nutrition_gemini': sanitizedGemini,
        'timestamp': Timestamp.fromDate(now),
      },
      SetOptions(merge: true),
    );
    await batch.commit();
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
    final prefix = (mealLabel != null && mealLabel.isNotEmpty)
        ? mealLabel.substring(0, 1).toUpperCase() + mealLabel.substring(1)
        : null;
    final fromGemini = _stringField(nut['dish_name']);
    if (fromGemini.isNotEmpty) {
      return prefix != null ? '$prefix: $fromGemini' : fromGemini;
    }
    final foodsRaw = nut['foods'];
    if (foodsRaw is List && foodsRaw.isNotEmpty) {
      final first = foodsRaw.first;
      final rawName = first is Map ? first['name']?.toString() : null;
      final name = (rawName != null && rawName.trim().isNotEmpty) ? rawName.trim() : 'Piatto';
      return prefix != null ? '$prefix: $name' : name;
    }
    return prefix ?? 'Piatto';
  }

  double _num(dynamic v) => (v is num) ? v.toDouble() : double.tryParse(v.toString()) ?? 0.0;

  static int _intFromFirestore(dynamic v) {
    if (v == null) return 0;
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) {
      return int.tryParse(v) ?? double.tryParse(v)?.toInt() ?? 0;
    }
    return 0;
  }

  static String _stringField(dynamic v) {
    if (v == null) return '';
    if (v is String) return v;
    return v.toString();
  }

  static List<String> _ingredientNamesFromFoods(dynamic foodsRaw) {
    if (foodsRaw is! List) return [];
    final out = <String>[];
    for (final f in foodsRaw) {
      if (f is Map) {
        final s = f['name']?.toString().trim() ?? '';
        if (s.isNotEmpty) out.add(s);
      }
    }
    return out;
  }

  /// Evita NaN/Inf e normalizza mappe annidate per Firestore (desktop Windows è più rigido).
  static Map<String, dynamic> _sanitizeForFirestoreMap(Map<String, dynamic> source) {
    dynamic walk(dynamic v) {
      if (v == null) return null;
      if (v is bool) return v;
      if (v is String) return v;
      if (v is Timestamp) return v;
      if (v is DateTime) return Timestamp.fromDate(v);
      if (v is int) return v;
      if (v is double) return v.isFinite ? v : 0.0;
      if (v is num) {
        final d = v.toDouble();
        return d.isFinite ? v : 0;
      }
      if (v is List) {
        return v.map(walk).toList();
      }
      if (v is Map) {
        final out = <String, dynamic>{};
        v.forEach((key, value) {
          out[key.toString()] = walk(value) as Object?;
        });
        return out;
      }
      return v.toString();
    }

    final root = walk(source);
    if (root is Map<String, dynamic>) return root;
    if (root is Map) return Map<String, dynamic>.from(root);
    return {};
  }

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