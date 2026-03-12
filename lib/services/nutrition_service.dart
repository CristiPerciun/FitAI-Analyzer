import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Servizio per salvataggio dati nutrizione (Gemini foto piatto) su Firestore.
/// Livello 1 - daily_logs.
final nutritionServiceProvider = Provider<NutritionService>((ref) => NutritionService());

class NutritionService {
  /// Salva i dati nutrizione nel daily_log del giorno.
  /// [uid] - ID utente Firebase
  /// [nutritionGemini] - Mappa con total_calories, protein_g, carbs_g, fat_g, etc.
  /// [date] - Data opzionale (default: oggi)
  Future<void> saveToFirestore(
    String uid,
    Map<String, dynamic> nutritionGemini, {
    DateTime? date,
  }) async {
    final dateStr = (date ?? DateTime.now()).toIso8601String().split('T')[0];

    final dailyRef = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('daily_logs')
        .doc(dateStr);

    final dailyLog = <String, dynamic>{
      'date': dateStr,
      'nutrition_gemini': nutritionGemini,
      'timestamp': Timestamp.fromDate(DateTime.now()),
    };

    await dailyRef.set(dailyLog, SetOptions(merge: true));
  }
}
