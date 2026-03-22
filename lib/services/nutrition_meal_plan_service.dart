import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fitai_analyzer/models/nutrition_meal_plan_ai.dart';
import 'package:fitai_analyzer/models/user_profile.dart';
import 'package:fitai_analyzer/services/ai_prompt_service.dart';
import 'package:fitai_analyzer/services/gemini_service.dart';

/// Piano alimentare AI (pagina Alimentazione): generazione JSON + salvataggio Firestore.
/// Path: `users/{uid}/nutrition_meal_plan/current`.
class NutritionMealPlanService {
  NutritionMealPlanService(
    this._firestore,
    this._gemini,
    this._aiPrompt,
  );

  final FirebaseFirestore _firestore;
  final GeminiService _gemini;
  final AiPromptService _aiPrompt;

  DocumentReference<Map<String, dynamic>> docRef(String uid) {
    return _firestore
        .collection('users')
        .doc(uid)
        .collection('nutrition_meal_plan')
        .doc('current');
  }

  Future<NutritionMealPlanAi?> fetch(String uid) async {
    final snap = await docRef(uid).get();
    if (!snap.exists || snap.data() == null) return null;
    return NutritionMealPlanAi.fromFirestore(snap.data()!);
  }

  Future<NutritionMealPlanAi> generateAndSave(String uid) async {
    final profileDoc = await _firestore
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

    final prompt = _aiPrompt.buildNutritionMealPlanPrompt(profile);
    final map = await _gemini.generateNutritionMealPlanJson(prompt);
    if (map.containsKey('error')) {
      throw StateError(map['error']?.toString() ?? 'Risposta Gemini non valida');
    }

    final plan = NutritionMealPlanAi.fromGeminiMap(map);
    await docRef(uid).set(plan.toFirestore(), SetOptions(merge: true));
    return plan;
  }
}
