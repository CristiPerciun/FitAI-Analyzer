import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/baseline_profile_model.dart';
import '../models/daily_log_model.dart';
import '../models/longevity_home_package.dart';
import '../models/rolling_10days_model.dart';

final longevityEngineProvider =
    Provider<LongevityEngine>((ref) => LongevityEngine());

/// Engine che aggrega dati da Livello 1 (daily_logs), Livello 2 (rolling_10days)
/// e Livello 3 (baseline_profile) per creare un unico pacchetto informativo
/// da inviare all'AI per popolare la Home.
///
/// Rispetta la strategia Tre Livelli: non legge sottocollezioni (meals),
/// usa solo campi di sintesi (nutrition_summary) per Livello 2/3.
class LongevityEngine {
  final _firestore = FirebaseFirestore.instance;

  /// Costruisce il pacchetto informativo unificato per la Home.
  /// Esegue 3 letture Firestore in parallelo (daily_logs oggi, rolling_10days, baseline_profile).
  Future<LongevityHomePackage> buildHomePackage(String uid) async {
    final todayStr = DateTime.now().toIso8601String().split('T')[0];

    final results = await Future.wait([
      _getTodayLog(uid, todayStr),
      _getRolling10Days(uid),
      _getBaseline(uid),
    ]);

    return LongevityHomePackage(
      today: results[0] as DailyLogModel?,
      rolling: results[1] as Rolling10DaysModel?,
      baseline: results[2] as BaselineProfileModel?,
    );
  }

  /// Restituisce il prompt pronto per l'AI (output di buildAiPrompt sul pacchetto).
  /// Comodo per inviare direttamente a GeminiService.
  Future<String> buildHomeAiPrompt(String uid) async {
    final package = await buildHomePackage(uid);
    return package.buildAiPrompt();
  }

  /// Prompt master per piano di longevità (4 micro-obiettivi + macro settimanale + consiglio strategico).
  Future<String> buildLongevityPlanPrompt(String uid) async {
    final package = await buildHomePackage(uid);
    return package.buildLongevityPlanPrompt();
  }

  Future<DailyLogModel?> _getTodayLog(String uid, String dateStr) async {
    final doc = await _firestore
        .collection('users')
        .doc(uid)
        .collection('daily_logs')
        .doc(dateStr)
        .get();

    if (!doc.exists || doc.data() == null) return null;

    final data = doc.data()!;
    return DailyLogModel.fromJson({
      ...data,
      'date': doc.id,
      'goal_today_ia': data['goal_today_ia'] ?? data['goal_today'] ?? '',
      'timestamp': data['timestamp'] ?? Timestamp.now(),
    });
  }

  Future<Rolling10DaysModel?> _getRolling10Days(String uid) async {
    final doc = await _firestore
        .collection('users')
        .doc(uid)
        .collection('rolling_10days')
        .doc('current')
        .get();

    if (!doc.exists || doc.data() == null) return null;

    return Rolling10DaysModel.fromJson(doc.data()!);
  }

  Future<BaselineProfileModel?> _getBaseline(String uid) async {
    final doc = await _firestore
        .collection('users')
        .doc(uid)
        .collection('baseline_profile')
        .doc('main')
        .get();

    if (!doc.exists || doc.data() == null) return null;

    return BaselineProfileModel.fromJson({...doc.data()!});
  }
}
