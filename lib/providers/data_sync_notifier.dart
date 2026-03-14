import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fitai_analyzer/models/fitness_data.dart';
import 'package:fitai_analyzer/providers/auth_notifier.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

export 'package:fitai_analyzer/utils/date_utils.dart' show formatDateForDisplay;

/// Stream provider per listen real-time ai dati Strava da Firestore.
final healthDataStreamProvider = StreamProvider.autoDispose<List<FitnessData>>(
  (ref) {
    final uid = ref.watch(authNotifierProvider).user?.uid;
    if (uid == null) return Stream.value([]);
    return FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('health_data')
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => FitnessData.fromJson({...d.data(), 'id': d.id}))
            .toList());
  },
);

/// Attività Strava raggruppate per data (più recente prima).
/// Chiave: "YYYY-MM-DD" per ordinamento, valore: lista ordinata per orario.
final activitiesByDateProvider = Provider.autoDispose<Map<String, List<FitnessData>>>((ref) {
  final healthAsync = ref.watch(healthDataStreamProvider);
  return healthAsync.when(
    data: (data) {
      final strava = data.where((d) => d.source == 'strava').toList();
      strava.sort((a, b) => b.date.compareTo(a.date)); // più recente prima
      final byDate = <String, List<FitnessData>>{};
      for (final a in strava) {
        final key = '${a.date.year}-${a.date.month.toString().padLeft(2, '0')}-${a.date.day.toString().padLeft(2, '0')}';
        byDate.putIfAbsent(key, () => []).add(a);
      }
      for (final list in byDate.values) {
        list.sort((a, b) => b.date.compareTo(a.date));
      }
      return byDate;
    },
    loading: () => <String, List<FitnessData>>{},
    error: (_, __) => <String, List<FitnessData>>{},
  );
});

/// Lista date (YYYY-MM-DD) ordinate dal più recente.
final activityDatesProvider = Provider.autoDispose<List<String>>((ref) {
  final byDate = ref.watch(activitiesByDateProvider);
  if (byDate.isEmpty) return [];
  final dates = byDate.keys.toList();
  dates.sort((a, b) => b.compareTo(a)); // YYYY-MM-DD ordina correttamente
  return dates;
});
