import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../models/baseline_profile_model.dart';
import '../models/daily_log_model.dart';
import '../models/rolling_10days_model.dart';

final aiPromptServiceProvider =
    Provider<AiPromptService>((ref) => AiPromptService());

class AiPromptService {
  static final _dateFormat = DateFormat('d MMM yyyy', 'it');

  /// Costruisce il contesto completo per prompt AI (Gemini/Grok).
  /// Un solo fetch → 8-10k token pronti per analisi scientifica personalizzata.
  Future<String> buildFullAIContext(String uid) async {
    final baseline = await _getBaseline(uid);
    final rolling = await _getRolling10Days(uid);
    final today = await _getTodayLog(uid);

    final baselineStr = baseline != null
        ? _dateFormat.format(baseline.lastBaselineUpdate)
        : 'non disponibile';

    final goalStr = baseline?.goal ?? today?.goalToday ?? 'dimagrire';

    final baselineSummary = baseline?.aiReadySummary ?? 'Nessun baseline ancora. Esegui prima la sincronizzazione Strava.';

    final rollingStr = rolling != null
        ? 'Distanza: ${rolling.totalDistanceKm.toStringAsFixed(1)} km | Zone 2: ${rolling.totalZone2Minutes} min | VO2 stimato: ${rolling.estimatedVo2Max.toStringAsFixed(1)}'
        : 'Nessun dato rolling ultimi 10 giorni.';

    final todayActivities = today?.stravaActivities.length ?? 0;
    final todayBurned = today?.totalBurnedKcal ?? 0.0;
    final todayNutrition = _formatNutrition(today?.nutritionForAi ?? {});

    return """
Utente obiettivo: $goalStr (dimagrire o massa muscolare).

BASELINE ANNUALE (aggiornata $baselineStr):
$baselineSummary

ULTIMI 10 GIORNI (dettagli completi):
$rollingStr

OGGI:
Attività: $todayActivities | Calorie bruciate: ${todayBurned.toStringAsFixed(0)} | Nutrizione Gemini: $todayNutrition

Riferimenti Peter Attia (Outlive) e studi:
- Zone 2 minimo 150-180 min/settimana
- VO2max >45 = ottimo longevità
- Forza + composizione corporea prioritari

Analizza in modo scientifico, personalizzato e approfondito. Dai piano settimanale concreto.
""";
  }

  Future<BaselineProfileModel?> _getBaseline(String uid) async {
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('baseline_profile')
        .doc('main')
        .get();

    if (!doc.exists || doc.data() == null) return null;

    return BaselineProfileModel.fromJson({...doc.data()!});
  }

  Future<Rolling10DaysModel?> _getRolling10Days(String uid) async {
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('rolling_10days')
        .doc('current')
        .get();

    if (!doc.exists || doc.data() == null) return null;

    return Rolling10DaysModel.fromJson(doc.data()!);
  }

  Future<DailyLogModel?> _getTodayLog(String uid) async {
    final todayStr = DateTime.now().toIso8601String().split('T')[0];

    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('daily_logs')
        .doc(todayStr)
        .get();

    if (!doc.exists || doc.data() == null) return null;

    final data = doc.data()!;
    return DailyLogModel.fromJson({
      ...data,
      'date': doc.id,
      'goal_today': data['goal_today'] ?? 'dimagrire',
      'timestamp': data['timestamp'] ?? Timestamp.now(),
    });
  }

  String _formatNutrition(Map<String, dynamic> nut) {
    if (nut.isEmpty) return 'nessun dato';

    final parts = <String>[];
    final cal = nut['total_calories'] ?? nut['total_kcal'] ?? nut['calories'];
    if (cal != null) parts.add('${(cal as num).round()} kcal');
    final p = nut['protein_g'] ?? nut['total_protein'] ?? nut['protein'];
    if (p != null) parts.add('P: ${(p as num).round()}g');
    final c = nut['carbs_g'] ?? nut['total_carbs'] ?? nut['carbs'];
    if (c != null) parts.add('C: ${(c as num).round()}g');
    final f = nut['fat_g'] ?? nut['total_fat'] ?? nut['fat'];
    if (f != null) parts.add('F: ${(f as num).round()}g');
    final longevity = nut['avg_longevity_score'];
    if (longevity != null) parts.add('Longevità: $longevity/10');

    return parts.isEmpty ? 'dati parziali' : parts.join(' | ');
  }
}
