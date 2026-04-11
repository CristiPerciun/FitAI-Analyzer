import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fitai_analyzer/models/daily_log_model.dart';
import 'package:fitai_analyzer/models/meal_model.dart';
import 'package:fitai_analyzer/providers/auth_notifier.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

String _italianWeekdayShort(int weekday) {
  const labels = ['Lu', 'Ma', 'Me', 'Gio', 'Ve', 'Sa', 'Do'];
  return labels[weekday - 1];
}

String _dateKey(DateTime d) {
  final m = d.month.toString().padLeft(2, '0');
  final day = d.day.toString().padLeft(2, '0');
  return '${d.year}-$m-$day';
}

DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

/// Lunedì della settimana ISO che contiene [day] (weekday Dart: 1 = lun … 7 = dom).
DateTime _mondayOfWeekContaining(DateTime day) {
  final d = _dateOnly(day);
  return d.subtract(Duration(days: d.weekday - 1));
}

/// Indice settimana nel diario alimentazione: 0 = settimana calendario corrente (lun–dom), 1 = precedente, ecc.
final nutritionDiaryWeekOffsetProvider =
    NotifierProvider<NutritionDiaryWeekOffsetNotifier, int>(
  NutritionDiaryWeekOffsetNotifier.new,
);

class NutritionDiaryWeekOffsetNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void setWeeksAgo(int weeksAgo) {
    if (weeksAgo < 0 || weeksAgo > 12) return;
    state = weeksAgo;
  }
}

Future<NutritionChartData> _fetchNutritionChartWindow(
  String uid,
  int weekOffset,
) async {
  final firestore = FirebaseFirestore.instance;
  final now = DateTime.now();
  final today = _dateOnly(now);
  final thisWeekMonday = _mondayOfWeekContaining(today);
  final weekMonday = thisWeekMonday.subtract(Duration(days: 7 * weekOffset));
  final weekSunday = weekMonday.add(const Duration(days: 6));
  final startKey = _dateKey(weekMonday);
  final endKey = _dateKey(weekSunday);

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
  final carbsData = <DailyNutrient>[];

  for (var i = 0; i < 7; i++) {
    final d = weekMonday.add(Duration(days: i));
    final key = _dateKey(d);
    final log = byDate[key];
    final label = _italianWeekdayShort(d.weekday);
    caloriesData.add(DailyNutrient(label, log?.totalKcal ?? 0));
    proteinData.add(DailyNutrient(label, log?.totalProteinG ?? 0));
    fatData.add(DailyNutrient(label, log?.totalFatG ?? 0));
    carbsData.add(DailyNutrient(label, log?.totalCarbsG ?? 0));
  }

  return NutritionChartData(
    caloriesData: caloriesData,
    proteinData: proteinData,
    fatData: fatData,
    carbsData: carbsData,
  );
}

/// Settimana calendario corrente (lun–dom) per [NutritionChartCard] — indipendente dal selettore settimane del diario.
final nutritionChartDataProvider = FutureProvider<NutritionChartData>((ref) async {
  final uid = ref.watch(authNotifierProvider.select((s) => s.user?.uid));
  if (uid == null) {
    return NutritionChartData.empty(weekOffset: 0);
  }
  return _fetchNutritionChartWindow(uid, 0);
});

/// Finestra 7 giorni per il grafico a barre impilate (rispetta [nutritionDiaryWeekOffsetProvider]).
final nutritionDiaryWeekChartDataProvider = FutureProvider<NutritionChartData>((ref) async {
  final uid = ref.watch(authNotifierProvider.select((s) => s.user?.uid));
  final weekOffset = ref.watch(nutritionDiaryWeekOffsetProvider);
  if (uid == null) {
    return NutritionChartData.empty(weekOffset: weekOffset);
  }
  return _fetchNutritionChartWindow(uid, weekOffset);
});

class NutritionChartData {
  final List<DailyNutrient> caloriesData;
  final List<DailyNutrient> proteinData;
  final List<DailyNutrient> fatData;
  final List<DailyNutrient> carbsData;

  const NutritionChartData({
    required this.caloriesData,
    required this.proteinData,
    required this.fatData,
    required this.carbsData,
  });

  factory NutritionChartData.empty({int weekOffset = 0}) {
    final now = DateTime.now();
    final today = _dateOnly(now);
    final thisWeekMonday = _mondayOfWeekContaining(today);
    final weekMonday = thisWeekMonday.subtract(Duration(days: 7 * weekOffset));
    DailyNutrient z(int i) {
      final d = weekMonday.add(Duration(days: i));
      return DailyNutrient(_italianWeekdayShort(d.weekday), 0);
    }

    return NutritionChartData(
      caloriesData: List.generate(7, z),
      proteinData: List.generate(7, z),
      fatData: List.generate(7, z),
      carbsData: List.generate(7, z),
    );
  }
}
