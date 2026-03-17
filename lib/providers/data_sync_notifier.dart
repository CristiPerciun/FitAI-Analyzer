import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fitai_analyzer/models/fitness_data.dart';
import 'package:fitai_analyzer/providers/auth_notifier.dart';
import 'package:fitai_analyzer/services/garmin_service.dart';
import 'package:fitai_analyzer/utils/platform_firestore_fix.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

export 'package:fitai_analyzer/utils/date_utils.dart' show formatDateForDisplay;

/// Stream provider per attività unificate (`activities`) da Firestore.
final activitiesStreamProvider = StreamProvider.autoDispose<List<FitnessData>>((
  ref,
) {
  final uid = ref.watch(authNotifierProvider).user?.uid;
  if (uid == null) return Stream.value([]);
  return ref.read(garminServiceProvider).activitiesStream(uid);
});

/// Stato connessione Garmin (da Firestore users/{uid}.garmin_linked).
/// Su Windows usa polling per evitare errori "non-platform thread".
final garminConnectedProvider = StreamProvider.autoDispose<bool>((ref) {
  final uid = ref.watch(authNotifierProvider).user?.uid;
  if (uid == null) return Stream.value(false);
  final docRef = FirebaseFirestore.instance.collection('users').doc(uid);
  return documentSnapshotStream(
    docRef,
  ).map((doc) => doc.data()?['garmin_linked'] == true);
});

/// Dati biometrici daily_health (passi, sonno, HRV, Body Battery) scritti da garmin-sync-server.
/// Usa daily_health/{date} - invalidare dopo sync-vitals.
final dailyHealthStreamProvider =
    StreamProvider.autoDispose<List<Map<String, dynamic>>>((ref) {
      final uid = ref.watch(authNotifierProvider).user?.uid;
      if (uid == null) return Stream.value([]);
      final query = FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('daily_health');
      return querySnapshotStream(query).map((snap) {
        final docs = snap.docs.map((d) => {...d.data(), 'date': d.id}).toList();
        docs.sort(
          (a, b) => (b['date'] as String).compareTo(a['date'] as String),
        );
        return docs;
      });
    });

/// Attività già unificate lato scrittura, raggruppate per data (più recente prima).
final activitiesByDateProvider =
    Provider.autoDispose<Map<String, List<FitnessData>>>((ref) {
      final all = [...(ref.watch(activitiesStreamProvider).valueOrNull ?? [])]
        ..sort((a, b) => b.date.compareTo(a.date));

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
