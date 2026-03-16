import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fitai_analyzer/models/fitness_data.dart';
import 'package:fitai_analyzer/models/garmin_daily_model.dart';
import 'package:fitai_analyzer/providers/auth_notifier.dart';
import 'package:fitai_analyzer/services/garmin_service.dart';
import 'package:fitai_analyzer/utils/platform_firestore_fix.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

export 'package:fitai_analyzer/utils/date_utils.dart' show formatDateForDisplay;

/// Stream provider per listen real-time ai dati Strava da Firestore.
/// Su Windows usa polling per evitare errori "non-platform thread".
final healthDataStreamProvider = StreamProvider.autoDispose<List<FitnessData>>(
  (ref) {
    final uid = ref.watch(authNotifierProvider).user?.uid;
    if (uid == null) return Stream.value([]);
    final query = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('health_data');
    return querySnapshotStream(query).map((snap) => snap.docs
        .map((d) => FitnessData.fromJson({...d.data(), 'id': d.id}))
        .toList());
  },
);

/// Stream provider per attività Garmin da Firestore (garmin-sync-server su fly.io).
final garminActivitiesStreamProvider =
    StreamProvider.autoDispose<List<FitnessData>>((ref) {
  final uid = ref.watch(authNotifierProvider).user?.uid;
  if (uid == null) return Stream.value([]);
  return ref.read(garminServiceProvider).garminActivitiesStream(uid).map(
        (list) => list.map(GarminService.toFitnessData).toList(),
      );
});

/// Stato connessione Garmin (da Firestore users/{uid}.garmin_linked).
/// Su Windows usa polling per evitare errori "non-platform thread".
final garminConnectedProvider = StreamProvider.autoDispose<bool>((ref) {
  final uid = ref.watch(authNotifierProvider).user?.uid;
  if (uid == null) return Stream.value(false);
  final docRef = FirebaseFirestore.instance.collection('users').doc(uid);
  return documentSnapshotStream(docRef).map((doc) => doc.data()?['garmin_linked'] == true);
});

/// Dati giornalieri Garmin per una data specifica.
final garminDailyProvider =
    FutureProvider.autoDispose.family<GarminDailyModel?, String>((ref, date) {
  final uid = ref.watch(authNotifierProvider).user?.uid;
  if (uid == null) return Future.value(null);
  return ref.read(garminServiceProvider).getDailyGarminData(uid, date);
});

/// Attività Strava + Garmin unificate, raggruppate per data (più recente prima).
/// Chiave: "YYYY-MM-DD", valore: lista ordinata per orario.
final activitiesByDateProvider =
    Provider.autoDispose<Map<String, List<FitnessData>>>((ref) {
  final healthAsync = ref.watch(healthDataStreamProvider);
  final garminAsync = ref.watch(garminActivitiesStreamProvider);

  final strava = (healthAsync.valueOrNull ?? []).where((d) => d.source == 'strava').toList();
  final garmin = garminAsync.valueOrNull ?? [];
  final all = [...strava, ...garmin];
  all.sort((a, b) => b.date.compareTo(a.date));

  final byDate = <String, List<FitnessData>>{};
  for (final a in all) {
    final key =
        '${a.date.year}-${a.date.month.toString().padLeft(2, '0')}-${a.date.day.toString().padLeft(2, '0')}';
    byDate.putIfAbsent(key, () => []).add(a);
  }
  for (final list in byDate.values) {
    list.sort((a, b) => b.date.compareTo(a.date));
  }
  return byDate;
});

/// Lista date (YYYY-MM-DD) ordinate dal più recente.
final activityDatesProvider = Provider.autoDispose<List<String>>((ref) {
  final byDate = ref.watch(activitiesByDateProvider);
  if (byDate.isEmpty) return [];
  final dates = byDate.keys.toList();
  dates.sort((a, b) => b.compareTo(a)); // YYYY-MM-DD ordina correttamente
  return dates;
});
