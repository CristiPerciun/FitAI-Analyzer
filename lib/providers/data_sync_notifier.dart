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

/// Dati biometrici daily_health (passi, sonno, HRV, Body Battery) scritti da garmin-sync-server.
/// Usa daily_health/{date} - invalidare dopo sync-vitals.
final dailyHealthStreamProvider = StreamProvider.autoDispose<List<Map<String, dynamic>>>(
  (ref) {
    final uid = ref.watch(authNotifierProvider).user?.uid;
    if (uid == null) return Stream.value([]);
    final query = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('daily_health');
    return querySnapshotStream(query).map((snap) {
      final docs = snap.docs.map((d) => {...d.data(), 'date': d.id}).toList();
      docs.sort((a, b) => (b['date'] as String).compareTo(a['date'] as String));
      return docs;
    });
  },
);

/// Dati giornalieri Garmin per una data specifica.
final garminDailyProvider =
    FutureProvider.autoDispose.family<GarminDailyModel?, String>((ref, date) {
  final uid = ref.watch(authNotifierProvider).user?.uid;
  if (uid == null) return Future.value(null);
  return ref.read(garminServiceProvider).getDailyGarminData(uid, date);
});

/// Tipo normalizzato per confronto.
String _normalizedActivityType(FitnessData d) {
  final t = d.activityType ?? d.raw?['sport_type'] ?? d.raw?['type'] ?? '';
  return t.toString().toLowerCase();
}

/// True se stesso tipo (run/running, ride/cycling, ecc.).
bool _sameActivityType(String ts, String tg) {
  const runLike = ['run', 'running'];
  const rideLike = ['ride', 'cycling', 'bike', 'virtualride'];
  const walkLike = ['walk', 'walking', 'hike', 'hiking'];
  if (runLike.contains(ts) && runLike.contains(tg)) return true;
  if (rideLike.contains(ts) && rideLike.contains(tg)) return true;
  if (walkLike.contains(ts) && walkLike.contains(tg)) return true;
  return ts == tg;
}

/// True se Strava [s] è duplicato di Garmin [g]: stessa data + stesso tipo + ora/distanza simili.
bool _isStravaDuplicateOfGarmin(FitnessData s, FitnessData g) {
  if (s.source != 'strava' || g.source != 'garmin') return false;
  final keyS = '${s.date.year}-${s.date.month}-${s.date.day}';
  final keyG = '${g.date.year}-${g.date.month}-${g.date.day}';
  if (keyS != keyG) return false;
  final ts = _normalizedActivityType(s);
  final tg = _normalizedActivityType(g);
  if (ts.isEmpty || tg.isEmpty) return false;
  if (!_sameActivityType(ts, tg)) return false;
  if (s.date.difference(g.date).abs().inMinutes > 15) return false;
  if (s.distanceKm != null && g.distanceKm != null && g.distanceKm! > 0) {
    final ratio = s.distanceKm! / g.distanceKm!;
    if (ratio < 0.85 || ratio > 1.15) return false;
  }
  return true;
}

/// Attività Strava + Garmin unificate, raggruppate per data (più recente prima).
/// Deduplicazione 1:1: stessa data + tipo + ora/distanza simili → solo Garmin.
final activitiesByDateProvider =
    Provider.autoDispose<Map<String, List<FitnessData>>>((ref) {
  final healthAsync = ref.watch(healthDataStreamProvider);
  final garminAsync = ref.watch(garminActivitiesStreamProvider);

  final strava = (healthAsync.valueOrNull ?? []).where((d) => d.source == 'strava').toList();
  final garmin = garminAsync.valueOrNull ?? [];
  final usedGarmin = List.filled(garmin.length, false);
  final stravaFiltered = strava.where((s) {
    for (var i = 0; i < garmin.length; i++) {
      if (usedGarmin[i]) continue;
      if (_isStravaDuplicateOfGarmin(s, garmin[i])) {
        usedGarmin[i] = true;
        return false;
      }
    }
    return true;
  }).toList();
  final all = [...garmin, ...stravaFiltered];
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
