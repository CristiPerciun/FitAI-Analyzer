import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fitai_analyzer/models/daily_log_model.dart';
import 'package:fitai_analyzer/models/meal_model.dart';

String _italianWeekdayShort(int weekday) {
  const labels = ['Lu', 'Ma', 'Me', 'Gio', 'Ve', 'Sa', 'Do'];
  return labels[weekday - 1];
}

String _dateKey(DateTime d) {
  final m = d.month.toString().padLeft(2, '0');
  final day = d.day.toString().padLeft(2, '0');
  return '${d.year}-$m-$day';
}

/// Ultimi 7 giorni (rolling) da `daily_logs`, allineati al calendario con etichette giorno.
final nutritionChartDataProvider = FutureProvider<NutritionChartData>((ref) async {
  final firestore = FirebaseFirestore.instance;
  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (uid == null) {
    return NutritionChartData.empty();
  }

  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final oldest = today.subtract(const Duration(days: 6));
  final startKey = _dateKey(oldest);
  final endKey = _dateKey(today);

  final snapshot = await firestore
      .collection('users')
      .doc(uid)
      .collection('daily_logs')
      .where(FieldPath.documentId, isGreaterThanOrEqualTo: startKey)
      .where(FieldPath.documentId, isLessThanOrEqualTo: endKey)
      .get();

  final byDate = <String, DailyLogModel>{};
  for (final doc in snapshot.docs) {
    byDate[doc.id] = DailyLogModel.fromJson({...doc.data(), 'date': doc.id});
  }

  final caloriesData = <DailyNutrient>[];
  final proteinData = <DailyNutrient>[];
  final fatData = <DailyNutrient>[];

  for (var i = 0; i < 7; i++) {
    final d = oldest.add(Duration(days: i));
    final key = _dateKey(d);
    final log = byDate[key];
    final label = _italianWeekdayShort(d.weekday);
    caloriesData.add(DailyNutrient(label, log?.totalKcal ?? 0));
    proteinData.add(DailyNutrient(label, log?.totalProteinG ?? 0));
    fatData.add(DailyNutrient(label, log?.totalFatG ?? 0));
  }

  return NutritionChartData(
    caloriesData: caloriesData,
    proteinData: proteinData,
    fatData: fatData,
  );
});

class NutritionChartData {
  final List<DailyNutrient> caloriesData;
  final List<DailyNutrient> proteinData;
  final List<DailyNutrient> fatData;

  const NutritionChartData({
    required this.caloriesData,
    required this.proteinData,
    required this.fatData,
  });

  factory NutritionChartData.empty() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final oldest = today.subtract(const Duration(days: 6));
    DailyNutrient z(int i) {
      final d = oldest.add(Duration(days: i));
      return DailyNutrient(_italianWeekdayShort(d.weekday), 0);
    }

    return NutritionChartData(
      caloriesData: List.generate(7, z),
      proteinData: List.generate(7, z),
      fatData: List.generate(7, z),
    );
  }
}
