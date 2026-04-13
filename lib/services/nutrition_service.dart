import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/meal_model.dart';
import '../models/user_profile.dart';
import '../utils/platform_firestore_fix.dart';
import 'ai_prompt_service.dart';
import 'unified_ai_service.dart';

/// Servizio per salvataggio dati nutrizione (Gemini foto piatto) su Firestore.
/// Strategia a Tre Livelli:
/// - Livello 1: meals subcollection (dettaglio singolo pasto)
/// - Livello 2: nutrition_summary su daily_log (trend settimanale)
/// - Livello 3: baseline_profile usa medie da nutrition_summary
final nutritionServiceProvider = Provider<NutritionService>((ref) {
  return NutritionService(
    aiPromptService: ref.read(aiPromptServiceProvider),
    unifiedAi: ref.read(unifiedAiServiceProvider),
  );
});

class NutritionService {
  NutritionService({
    required AiPromptService aiPromptService,
    required UnifiedAiService unifiedAi,
  })  : _aiPromptService = aiPromptService,
        _unifiedAi = unifiedAi;

  final AiPromptService _aiPromptService;
  final UnifiedAiService _unifiedAi;

  /// Soglia grezza: oltre questa dimensione non salviamo la miniatura su Firestore (limite doc).
  static const int _maxMealThumbBytes = 220 * 1024;

  /// Scrive sempre `meal_doc_id` nel body (retrocompat. se lo snapshot perde l'id lato client).
  static Map<String, dynamic> _mealWritePayload(MealModel meal, String documentId) {
    return {...meal.toFirestore(), 'meal_doc_id': documentId};
  }

  static String? _mealThumbBase64FromBytes(Uint8List? raw) {
    if (raw == null || raw.isEmpty) return null;
    if (raw.length > _maxMealThumbBytes) return null;
    return base64Encode(raw);
  }

  /// Salva il pasto nella sottocollezione meals e aggiorna nutrition_summary sul daily_log.
  /// Usa il **NUOVO MealModel** (campi flat proteinG / carbsG / fatG + ingredients + aiConfidence).
  /// Con [existingMealId] aggiorna il documento e ricalcola il summary (no duplicati).
  Future<String> saveToFirestore(
    String uid,
    Map<String, dynamic> nutritionGemini, {
    String? mealLabel,
    DateTime? date,
    Uint8List? mealPhotoBytes,
    String? existingMealId,
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
    final portionG = _num(
      nutritionGemini['portion_grams'] ?? nutritionGemini['estimated_portion_grams'] ?? 0,
    );
    final portionGrams = portionG > 0 ? portionG : null;

    final advice = _stringField(nutritionGemini['advice']);
    final longevityScore = _num(nutritionGemini['longevity_score'] ?? 0);

    // Parsing ingredienti (senza cast che possano fallire su JSON eterogeneo)
    final ingredients = _ingredientNamesFromFoods(nutritionGemini['foods']);

    final mealType = (mealLabel != null && mealLabel.isNotEmpty)
        ? mealLabel.substring(0, 1).toUpperCase() + mealLabel.substring(1)
        : 'Pasto';

    final dailySnap = await dailyRef.get();
    final currentData = dailySnap.data() ?? {};
    final rawSummary = currentData['nutrition_summary'];
    var existingSummary = rawSummary is Map
        ? Map<String, dynamic>.from(rawSummary)
        : <String, dynamic>{};

    MealModel? oldMeal;
    DocumentReference<Map<String, dynamic>>? mealRef;

    if (existingMealId != null && existingMealId.isNotEmpty) {
      mealRef = mealsRef.doc(existingMealId);
      final oldSnap = await mealRef.get();
      if (!oldSnap.exists || oldSnap.data() == null) {
        throw StateError('Pasto da aggiornare non trovato');
      }
      oldMeal = MealModel.fromFirestore(oldSnap.data()!, documentId: existingMealId);
      final totalKcal = _num(existingSummary['total_kcal'] ?? 0) - oldMeal.calories + calories;
      final totalProtein = _num(existingSummary['total_protein_g'] ?? existingSummary['total_protein'] ?? 0) -
          oldMeal.proteinG +
          proteinG;
      final totalCarbs = _num(existingSummary['total_carbs_g'] ?? existingSummary['total_carbs'] ?? 0) -
          oldMeal.carbsG +
          carbsG;
      final totalFat = _num(existingSummary['total_fat_g'] ?? existingSummary['total_fat'] ?? 0) -
          oldMeal.fatG +
          fatG;

      final thumb = _mealThumbBase64FromBytes(mealPhotoBytes) ?? oldMeal.mealThumbBase64;

      final meal = MealModel(
        dishName: dishName,
        calories: calories.round(),
        proteinG: proteinG,
        carbsG: carbsG,
        fatG: fatG,
        portionGrams: portionGrams,
        ingredients: ingredients,
        timestamp: oldMeal.timestamp,
        mealType: oldMeal.mealType.isNotEmpty ? oldMeal.mealType : mealType,
        rawAiAnalysis: advice.isNotEmpty ? advice : oldMeal.rawAiAnalysis,
        aiConfidence: 0.85,
        firestoreDocumentId: existingMealId,
        mealThumbBase64: thumb,
      );

      final longevitySum = _num(existingSummary['_longevity_sum'] ?? 0);
      final longevityCount = _intFromFirestore(existingSummary['_longevity_count']);

      final nutritionSummary = <String, dynamic>{
        'total_kcal': totalKcal.round().clamp(0, 1 << 30),
        'total_protein_g': totalProtein.round().clamp(0, 1 << 30),
        'total_carbs_g': totalCarbs.round().clamp(0, 1 << 30),
        'total_fat_g': totalFat.round().clamp(0, 1 << 30),
        'meals_count': _intFromFirestore(existingSummary['meals_count']).clamp(0, 1 << 20),
        'avg_longevity_score': longevityCount > 0
            ? (longevitySum / longevityCount).toStringAsFixed(1)
            : null,
        '_longevity_sum': longevitySum,
        '_longevity_count': longevityCount,
      };

      final sanitizedGemini =
          _sanitizeForFirestoreMap(Map<String, dynamic>.from(nutritionGemini));

      final batch = firestore.batch();
      batch.update(mealRef, _mealWritePayload(meal, existingMealId));
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
      return existingMealId;
    }

    final thumbNew = _mealThumbBase64FromBytes(mealPhotoBytes);

    // ====================== NUOVO MEALMODEL ======================
    final meal = MealModel(
      dishName: dishName,
      calories: calories.round(),
      proteinG: proteinG,
      carbsG: carbsG,
      fatG: fatG,
      portionGrams: portionGrams,
      ingredients: ingredients,
      timestamp: timeStr,
      mealType: mealType,
      rawAiAnalysis: advice,
      aiConfidence: 0.85, // default (migliorabile in futuro con score Gemini)
      mealThumbBase64: thumbNew,
    );

    // Lettura + batch (no runTransaction): su Windows il client Firestore C++ va spesso
    // in abort() con le transazioni; iOS/Android reggono meglio ma il batch è equivalente
    // per questo flusso (piccola race se due salvataggi simultanei sullo stesso giorno).
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

    mealRef = mealsRef.doc();
    final batch = firestore.batch();
    batch.set(mealRef, _mealWritePayload(meal, mealRef.id));
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
    return mealRef.id;
  }

  /// Elimina un pasto da `meals/{mealId}` e sottrae i macro dal `nutrition_summary` del giorno.
  Future<void> deleteMeal(String uid, String dateStr, String mealId) async {
    if (mealId.isEmpty) throw ArgumentError('mealId vuoto');

    final firestore = FirebaseFirestore.instance;
    final dailyRef = firestore
        .collection('users')
        .doc(uid)
        .collection('daily_logs')
        .doc(dateStr);
    final mealRef = dailyRef.collection('meals').doc(mealId);

    final mealSnap = await mealRef.get();
    if (!mealSnap.exists || mealSnap.data() == null) {
      throw StateError('Pasto non trovato');
    }
    final deleted = MealModel.fromFirestore(mealSnap.data()!, documentId: mealId);

    final dailySnap = await dailyRef.get();
    final currentData = dailySnap.data() ?? {};
    final rawSummary = currentData['nutrition_summary'];
    final existingSummary = rawSummary is Map
        ? Map<String, dynamic>.from(rawSummary)
        : <String, dynamic>{};

    final totalKcal =
        (_num(existingSummary['total_kcal'] ?? 0) - deleted.calories).clamp(0.0, 1 << 30);
    final totalProtein = (_num(
              existingSummary['total_protein_g'] ?? existingSummary['total_protein'] ?? 0,
            ) -
            deleted.proteinG)
        .clamp(0.0, 1 << 30);
    final totalCarbs = (_num(
              existingSummary['total_carbs_g'] ?? existingSummary['total_carbs'] ?? 0,
            ) -
            deleted.carbsG)
        .clamp(0.0, 1 << 30);
    final totalFat = (_num(
              existingSummary['total_fat_g'] ?? existingSummary['total_fat'] ?? 0,
            ) -
            deleted.fatG)
        .clamp(0.0, 1 << 30);

    final mealsCount = (_intFromFirestore(existingSummary['meals_count']) - 1).clamp(0, 1 << 20);

    final longevitySum = _num(existingSummary['_longevity_sum'] ?? 0);
    final longevityCount = _intFromFirestore(existingSummary['_longevity_count']);

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

    final now = DateTime.now();
    final batch = firestore.batch();
    batch.delete(mealRef);
    batch.set(
      dailyRef,
      {
        'date': dateStr,
        'nutrition_summary': nutritionSummary,
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
    final plan = await _unifiedAi.generateFromPrompt(prompt);

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

  /// Trova l'id documento `meals/{id}` confrontando i campi (pasti senza id in memoria).
  Future<String?> resolveMealDocumentId(
    String uid,
    String dateStr,
    MealModel meal,
  ) async {
    if (meal.firestoreDocumentId != null && meal.firestoreDocumentId!.isNotEmpty) {
      return meal.firestoreDocumentId;
    }
    final col = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('daily_logs')
        .doc(dateStr)
        .collection('meals');
    final snapshot = await col.get();
    for (final d in snapshot.docs) {
      final other = MealModel.fromFirestore(d.data(), documentId: d.id);
      if (other.dishName == meal.dishName &&
          other.timestamp == meal.timestamp &&
          other.calories == meal.calories &&
          (other.proteinG - meal.proteinG).abs() < 0.01) {
        return d.id;
      }
    }
    for (final d in snapshot.docs) {
      final other = MealModel.fromFirestore(d.data(), documentId: d.id);
      if (other.dishName == meal.dishName && other.timestamp == meal.timestamp) {
        return d.id;
      }
    }
    return null;
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
        .map((d) => MealModel.fromFirestore(
              d.data(),
              documentId: d.id.isNotEmpty ? d.id : null,
            ))
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
        .map((d) => MealModel.fromFirestore(
              d.data(),
              documentId: d.id.isNotEmpty ? d.id : null,
            ))
        .toList());
  }
}