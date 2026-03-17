import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/baseline_profile_model.dart';
import '../models/daily_log_model.dart';
import '../models/rolling_10days_model.dart';
import 'gemini_api_key_service.dart';
import 'gemini_service.dart';

final aggregationServiceProvider = Provider<AggregationService>((ref) {
  return AggregationService(
    geminiService: ref.read(geminiServiceProvider),
    geminiApiKeyService: ref.read(geminiApiKeyServiceProvider),
  );
});

class AggregationService {
  AggregationService({
    required GeminiService geminiService,
    required GeminiApiKeyService geminiApiKeyService,
  })  : _geminiService = geminiService,
        _geminiApiKeyService = geminiApiKeyService;

  final GeminiService _geminiService;
  final GeminiApiKeyService _geminiApiKeyService;

  static const int _baselineUpdateIntervalDays = 10;

  /// Estrae campi da attività Strava o Garmin (formati nativi, nessuna conversione).
  static double _actDistanceM(Map<String, dynamic> act) {
    final d = (act['distance'] as num?)?.toDouble() ?? 0;
    if (d > 0 && d < 100) return d * 1000; // Garmin a volte in km
    return d;
  }

  static int _actElapsedSec(Map<String, dynamic> act) {
    final e = act['elapsed_time'] ?? act['moving_time'];
    if (e != null) return (e as num).toInt();
    final d = act['duration'] ?? act['movingDuration'];
    return (d as num?)?.toInt() ?? 0;
  }

  static double? _actAvgHr(Map<String, dynamic> act) {
    final v = act['average_heartrate'] ?? act['averageHR'] ?? act['averageHeartRate'];
    return (v as num?)?.toDouble();
  }

  static double? _actMaxHr(Map<String, dynamic> act) {
    final v = act['max_heartrate'] ?? act['maxHR'] ?? act['maxHeartRate'];
    return (v as num?)?.toDouble();
  }

  static String _actSportType(Map<String, dynamic> act) {
    final t = act['sport_type'] ?? act['type'];
    if (t != null) return t.toString().toLowerCase();
    final tk = act['activityTypeKey']?.toString();
    if (tk != null && tk.isNotEmpty) return tk.toLowerCase();
    final g = act['activityType'];
    if (g is Map) return ((g['typeKey'] ?? g['typeId'])?.toString() ?? '').toLowerCase();
    return (g?.toString() ?? '').toLowerCase();
  }

  /// Aggiorna Livello 2 (rolling_10days) e, se necessario, Livello 3 (baseline_profile).
  Future<void> updateRolling10DaysAndBaseline(String uid) async {
    final firestore = FirebaseFirestore.instance;
    final dailyLogsRef = firestore
        .collection('users')
        .doc(uid)
        .collection('daily_logs');

    // 1. Leggi ultimi 10 daily_logs (ordinati per data desc)
    final today = DateTime.now();
    final tenDaysAgo = today.subtract(const Duration(days: 10));
    final startDateStr = tenDaysAgo.toIso8601String().split('T')[0];
    final endDateStr = today.toIso8601String().split('T')[0];

    final snapshot = await dailyLogsRef
        .where(FieldPath.documentId, isGreaterThanOrEqualTo: startDateStr)
        .where(FieldPath.documentId, isLessThanOrEqualTo: endDateStr)
        .orderBy(FieldPath.documentId, descending: true)
        .limit(10)
        .get();

    final dailyLogs = snapshot.docs.map((d) {
      final data = d.data();
      return DailyLogModel.fromJson({
        ...data,
        'date': d.id,
        'goal_today_ia': data['goal_today_ia'] ?? data['goal_today'] ?? '',
        'timestamp': data['timestamp'] ?? Timestamp.now(),
      });
    }).toList();

    // Ordina per data crescente (dal più vecchio al più recente)
    dailyLogs.sort((a, b) => a.date.compareTo(b.date));

    // 2. Calcola aggregati
    final rolling = _computeRolling10Days(dailyLogs);

    // 3. Salva in rolling_10days/current
    await firestore
        .collection('users')
        .doc(uid)
        .collection('rolling_10days')
        .doc('current')
        .set(rolling.toJson());

    // 4. Verifica se aggiornare baseline (ogni 10 giorni)
    final baselineRef = firestore
        .collection('users')
        .doc(uid)
        .collection('baseline_profile')
        .doc('main');

    final baselineDoc = await baselineRef.get();
    DateTime? lastBaseline = baselineDoc.exists
        ? (baselineDoc.data()?['last_baseline_update'] as Timestamp?)?.toDate()
        : null;

    final shouldUpdateBaseline = lastBaseline == null ||
        today.difference(lastBaseline).inDays >= _baselineUpdateIntervalDays;

    if (shouldUpdateBaseline) {
      final baseline = await _computeBaselineProfile(
        uid: uid,
        firestore: firestore,
        dailyLogs: dailyLogs,
        rolling: rolling,
      );
      await baselineRef.set(baseline.toJson());
    }
  }

  Rolling10DaysModel _computeRolling10Days(List<DailyLogModel> dailyLogs) {
    double totalDistanceKm = 0;
    int totalZone2Minutes = 0;
    double sumHr = 0;
    int hrCount = 0;
    double? bestVo2FromPace;
    final activitiesSummary = <Map<String, dynamic>>[];
    final macroSums = <String, double>{'protein_g': 0, 'carbs_g': 0, 'fat_g': 0, 'calories': 0};
    int macroDays = 0;

    for (final log in dailyLogs) {
      double dayDistance = 0;
      int dayZone2Min = 0;
      double? dayAvgHr;
      double? dayMaxHr;

      final activities = log.activitiesForAggregation;
      for (final act in activities) {
        final distM = _actDistanceM(act);
        final distKm = distM / 1000;
        dayDistance += distKm;

        final elapsedSec = _actElapsedSec(act);
        final elapsedMin = elapsedSec / 60;

        final avgHr = _actAvgHr(act);
        final maxHr = _actMaxHr(act);

        if (avgHr != null) {
          dayAvgHr ??= 0;
          dayAvgHr = (dayAvgHr * (hrCount > 0 ? 1 : 0) + avgHr) / (hrCount + 1);
          sumHr += avgHr;
          hrCount++;
        }
        if (maxHr != null) dayMaxHr = dayMaxHr != null ? (dayMaxHr > maxHr ? dayMaxHr : maxHr) : maxHr;

        // Zone 2 stimato: 60-70% max HR (Peter Attia). Se avg in range, conta minuti.
        final maxForZone2 = maxHr ?? 180; // fallback
        final zone2Low = maxForZone2 * 0.60;
        final zone2High = maxForZone2 * 0.70;
        if (avgHr != null && avgHr >= zone2Low && avgHr <= zone2High) {
          dayZone2Min += elapsedMin.round();
        } else if (avgHr != null && avgHr < zone2High) {
          // Sotto zona 2: conta metà come "cardio leggero"
          dayZone2Min += (elapsedMin * 0.5).round();
        }
      }

      totalDistanceKm += dayDistance;
      totalZone2Minutes += dayZone2Min;

      // VO2max stimato da pace corsa (formula semplificata: pace 5 min/km ≈ 50 VO2)
      for (final act in activities) {
        final sport = _actSportType(act);
        if (sport.contains('run')) {
          final distM = _actDistanceM(act);
          final movingSec = _actElapsedSec(act);
          if (distM > 0 && movingSec > 0) {
            final paceMinPerKm = (movingSec / 60) / (distM / 1000);
            // Formula semplificata: VO2 ≈ 2.8 + 3.5 * (1000/pace_sec_per_km)
            final vo2 = 2.8 + (3.5 * 1000 / (paceMinPerKm * 60));
            final current = bestVo2FromPace;
            if (current == null || vo2 > current) {
              bestVo2FromPace = vo2;
            }
          }
        }
      }

      activitiesSummary.add({
        'date': log.date,
        'distance_km': dayDistance,
        'zone2_minutes': dayZone2Min,
        'total_burned_kcal': log.totalBurnedKcalForAggregation,
      });

      // Macro: preferisce nutrition_summary (Livello 2), fallback a nutrition_gemini
      final nut = log.nutritionForAi;
      if (nut.isNotEmpty) {
        macroDays++;
        macroSums['protein_g'] = macroSums['protein_g']! +
            ((nut['protein_g'] ?? nut['total_protein'] ?? nut['protein'] ?? 0) as num).toDouble();
        macroSums['carbs_g'] = macroSums['carbs_g']! +
            ((nut['carbs_g'] ?? nut['total_carbs'] ?? nut['carbs'] ?? 0) as num).toDouble();
        macroSums['fat_g'] = macroSums['fat_g']! +
            ((nut['fat_g'] ?? nut['total_fat'] ?? nut['fat'] ?? 0) as num).toDouble();
        macroSums['calories'] = macroSums['calories']! +
            ((nut['total_calories'] ?? nut['total_kcal'] ?? nut['calories'] ?? 0) as num).toDouble();
      }
    }

    final avgHr = hrCount > 0 ? sumHr / hrCount : 0.0;
    final estimatedVo2 = bestVo2FromPace ?? 35.0 + (totalDistanceKm / 10);

    final macroAverages = <String, double>{};
    if (macroDays > 0) {
      for (final e in macroSums.entries) {
        macroAverages[e.key] = e.value / macroDays;
      }
    }

    return Rolling10DaysModel(
      activitiesSummary: activitiesSummary,
      totalDistanceKm: totalDistanceKm,
      totalZone2Minutes: totalZone2Minutes,
      avgHr: avgHr,
      macroAverages: macroAverages,
      estimatedVo2Max: estimatedVo2,
      lastUpdated: DateTime.now(),
    );
  }

  Future<BaselineProfileModel> _computeBaselineProfile({
    required String uid,
    required FirebaseFirestore firestore,
    required List<DailyLogModel> dailyLogs,
    required Rolling10DaysModel rolling,
  }) async {
    final year = DateTime.now().year;
    final startOfYear = '$year-01-01';
    final todayStr = DateTime.now().toIso8601String().split('T')[0];

    final snapshot = await firestore
        .collection('users')
        .doc(uid)
        .collection('daily_logs')
        .where(FieldPath.documentId, isGreaterThanOrEqualTo: startOfYear)
        .where(FieldPath.documentId, isLessThanOrEqualTo: todayStr)
        .get();

    final allLogs = snapshot.docs.map((d) {
      final data = d.data();
      return DailyLogModel.fromJson({
        ...data,
        'date': d.id,
        'goal_today_ia': data['goal_today_ia'] ?? data['goal_today'] ?? '',
        'timestamp': data['timestamp'] ?? Timestamp.now(),
      });
    }).toList();
    allLogs.sort((a, b) => a.date.compareTo(b.date));

    // Goal IA: da daily_logs più frequente (goal_today_ia creato dall'IA)
    String goalIa = '';
    final goalCounts = <String, int>{};
    for (final log in allLogs) {
      final g = log.goalTodayIa;
      if (g.isNotEmpty) {
        goalCounts[g] = (goalCounts[g] ?? 0) + 1;
      }
    }
    if (goalCounts.isNotEmpty) {
      goalIa = goalCounts.entries.reduce((a, b) => a.value > b.value ? a : b).key;
    }

    // Annual stats
    double totalKm = 0;
    int totalWorkouts = 0;
    double weightSum = 0;
    int weightCount = 0;
    double nutritionKcalSum = 0;
    double nutritionProteinSum = 0;
    double nutritionLongevitySum = 0;
    int nutritionDaysCount = 0;
    for (final log in allLogs) {
      for (final act in log.activitiesForAggregation) {
        totalKm += ((act['distance'] as num?)?.toDouble() ?? 0) / 1000;
        totalWorkouts++;
      }
      if (log.weightKg != null) {
        weightSum += log.weightKg!;
        weightCount++;
      }
      // Livello 3: medie nutrition_summary per biografia annuale
      final nut = log.nutritionForAi;
      if (nut.isNotEmpty) {
        nutritionDaysCount++;
        nutritionKcalSum += ((nut['total_calories'] ?? nut['total_kcal'] ?? 0) as num).toDouble();
        nutritionProteinSum += ((nut['protein_g'] ?? nut['total_protein'] ?? 0) as num).toDouble();
        final longevity = nut['avg_longevity_score'];
        if (longevity != null) {
          nutritionLongevitySum += (double.tryParse(longevity.toString()) ?? 0);
        }
      }
    }

    final annualStats = <String, dynamic>{
      'total_km_$year': totalKm,
      'total_workouts': totalWorkouts,
      'avg_weight': weightCount > 0 ? weightSum / weightCount : null,
      'avg_daily_kcal': nutritionDaysCount > 0 ? nutritionKcalSum / nutritionDaysCount : null,
      'avg_daily_protein': nutritionDaysCount > 0 ? nutritionProteinSum / nutritionDaysCount : null,
      'avg_longevity_score': nutritionDaysCount > 0 ? nutritionLongevitySum / nutritionDaysCount : null,
    };

    // Monthly trends (12 mesi) - incl. medie nutrition per Livello 3
    final monthlyTrends = <Map<String, dynamic>>[];
    for (var m = 1; m <= 12; m++) {
      final monthStr = m.toString().padLeft(2, '0');
      final monthLogs = allLogs.where((l) => l.date.startsWith('$year-$monthStr')).toList();
      double mKm = 0;
      int mWorkouts = 0;
      double mKcal = 0;
      double mProtein = 0;
      double mLongevity = 0;
      int mNutDays = 0;
      for (final log in monthLogs) {
        for (final act in log.activitiesForAggregation) {
          mKm += ((act['distance'] as num?)?.toDouble() ?? 0) / 1000;
          mWorkouts++;
        }
        final nut = log.nutritionForAi;
        if (nut.isNotEmpty) {
          mNutDays++;
          mKcal += ((nut['total_calories'] ?? nut['total_kcal'] ?? 0) as num).toDouble();
          mProtein += ((nut['protein_g'] ?? nut['total_protein'] ?? 0) as num).toDouble();
          final longevity = nut['avg_longevity_score'];
          if (longevity != null) mLongevity += (double.tryParse(longevity.toString()) ?? 0);
        }
      }
      monthlyTrends.add({
        'month': m,
        'year': year,
        'total_km': mKm,
        'workouts': mWorkouts,
        'avg_kcal': mNutDays > 0 ? mKcal / mNutDays : null,
        'avg_protein': mNutDays > 0 ? mProtein / mNutDays : null,
        'avg_longevity_score': mNutDays > 0 ? mLongevity / mNutDays : null,
      });
    }

    // Key metrics Attia (Outlive)
    final zone2Weekly = (rolling.totalZone2Minutes / 10) * 7; // media settimanale
    final keyMetricsAttia = <String, dynamic>{
      'estimated_vo2': rolling.estimatedVo2Max,
      'zone2_volume_weekly_avg': zone2Weekly.round(),
      'strength_score': 75, // placeholder - da integrare con dati forza
      'visceral_fat_estimate': 'basso', // placeholder - da composizione corporea
      'hr_recovery_avg': 45, // placeholder - da dati HR
    };

    // Evolution notes e ai_ready_summary: generati con AI ogni 10 giorni (strategia Tre Livelli)
    String evolutionNotes;
    String aiReadySummary;
    try {
      if (await _geminiApiKeyService.hasValidKey()) {
        final aiResult = await _generateBaselineWithAi(
          goalIa: goalIa,
          annualStats: annualStats,
          keyMetricsAttia: keyMetricsAttia,
          monthlyTrends: monthlyTrends,
          rolling: rolling,
          allLogs: allLogs,
          year: year,
        );
        evolutionNotes = aiResult.evolutionNotes;
        aiReadySummary = aiResult.aiReadySummary;
      } else {
        evolutionNotes = _buildEvolutionNotes(
          allLogs: allLogs,
          annualStats: annualStats,
          year: year,
        );
        aiReadySummary = _buildAiReadySummary(
          goalIa: goalIa,
          annualStats: annualStats,
          keyMetricsAttia: keyMetricsAttia,
          monthlyTrends: monthlyTrends,
          evolutionNotes: evolutionNotes,
          rolling: rolling,
        );
      }
    } catch (_) {
      // Fallback se AI fallisce
      evolutionNotes = _buildEvolutionNotes(
        allLogs: allLogs,
        annualStats: annualStats,
        year: year,
      );
      aiReadySummary = _buildAiReadySummary(
        goalIa: goalIa,
        annualStats: annualStats,
        keyMetricsAttia: keyMetricsAttia,
        monthlyTrends: monthlyTrends,
        evolutionNotes: evolutionNotes,
        rolling: rolling,
      );
    }

    return BaselineProfileModel(
      goalIa: goalIa,
      annualStats: annualStats,
      monthlyTrends: monthlyTrends,
      keyMetricsAttia: keyMetricsAttia,
      evolutionNotes: evolutionNotes,
      aiReadySummary: aiReadySummary,
      lastBaselineUpdate: DateTime.now(),
      references: [
        'Outlive - Peter Attia (Zone 2, longevità)',
        'Università Stanford - VO2max e mortalità',
        'ACSM - Linee guida esercizio cardiovascolare',
      ],
    );
  }

  /// Genera evolution_notes e ai_ready_summary con AI (baseline aggiornato ogni 10 gg con AI).
  Future<({String evolutionNotes, String aiReadySummary})> _generateBaselineWithAi({
    required String goalIa,
    required Map<String, dynamic> annualStats,
    required Map<String, dynamic> keyMetricsAttia,
    required List<Map<String, dynamic>> monthlyTrends,
    required Rolling10DaysModel rolling,
    required List<DailyLogModel> allLogs,
    required int year,
  }) async {
    final fallbackEvolution = _buildEvolutionNotes(
      allLogs: allLogs,
      annualStats: annualStats,
      year: year,
    );
    final fallbackSummary = _buildAiReadySummary(
      goalIa: goalIa,
      annualStats: annualStats,
      keyMetricsAttia: keyMetricsAttia,
      monthlyTrends: monthlyTrends,
      evolutionNotes: fallbackEvolution,
      rolling: rolling,
    );

    final prompt = '''
Sei un esperto di longevità (Peter Attia, Outlive). Genera il profilo baseline per un utente FitAI Analyzer.

DATI RAW:
- goal_ia: $goalIa
- annual_stats: ${annualStats.toString()}
- key_metrics_attia: ${keyMetricsAttia.toString()}
- monthly_trends: ${monthlyTrends.map((m) => 'Mese ${m['month']}: km=${m['total_km']}, workouts=${m['workouts']}, avg_kcal=${m['avg_kcal']}, avg_protein=${m['avg_protein']}').join('; ')}
- rolling 10gg: ${rolling.totalDistanceKm} km, Zone 2: ${rolling.totalZone2Minutes} min, VO2: ${rolling.estimatedVo2Max.toStringAsFixed(1)}

Restituisci un JSON con esattamente questi campi:
{
  "evolution_notes": "stringa 100-300 caratteri: note evolutive sintetiche (es. Da gennaio a marzo hai percorso X km, peso medio Y kg, progressione per longevità)",
  "ai_ready_summary": "stringa 4000+ caratteri: profilo completo AI-ready con statistiche annuali, metriche Attia, trend mensili, evoluzione, riferimenti Outlive/Stanford. Formato come _buildAiReadySummary ma arricchito con insight personalizzati"
}

Rispondi SOLO con il JSON, nessun altro testo.
''';

    try {
      final response = await _geminiService.generateFromPrompt(prompt);
      final cleaned = response
          .replaceAll(RegExp(r'```json\s*'), '')
          .replaceAll(RegExp(r'\s*```'), '')
          .trim();
      final decoded = json.decode(cleaned) as Map<String, dynamic>?;
      if (decoded != null) {
        final ev = decoded['evolution_notes']?.toString();
        final sum = decoded['ai_ready_summary']?.toString();
        if (ev != null && ev.isNotEmpty && sum != null && sum.length >= 500) {
          return (evolutionNotes: ev, aiReadySummary: sum);
        }
      }
    } catch (_) {
      // Fallback
    }
    return (evolutionNotes: fallbackEvolution, aiReadySummary: fallbackSummary);
  }

  String _buildEvolutionNotes({
    required List<DailyLogModel> allLogs,
    required Map<String, dynamic> annualStats,
    required int year,
  }) {
    if (allLogs.isEmpty) return 'Nessun dato sufficiente per analisi evolutiva.';

    final totalKm = (annualStats['total_km_$year'] as num?)?.toDouble() ?? 0;
    final workouts = annualStats['total_workouts'] as int? ?? 0;
    final avgWeight = annualStats['avg_weight'] as double?;

    final firstDate = allLogs.first.date;
    final lastDate = allLogs.last.date;

    final sb = StringBuffer();
    sb.write('Da $firstDate a $lastDate: ');
    sb.write('$totalKm km totali, $workouts allenamenti. ');
    if (avgWeight != null) {
      sb.write('Peso medio: ${avgWeight.toStringAsFixed(1)} kg. ');
    }
    sb.write('Progressione tracciata per ottimizzare obiettivi di longevità.');

    return sb.toString();
  }

  String _buildAiReadySummary({
    required String goalIa,
    required Map<String, dynamic> annualStats,
    required Map<String, dynamic> keyMetricsAttia,
    required List<Map<String, dynamic>> monthlyTrends,
    required String evolutionNotes,
    required Rolling10DaysModel rolling,
  }) {
    final year = DateTime.now().year;
    final totalKm = (annualStats['total_km_$year'] as num?)?.toDouble() ?? 0;
    final workouts = annualStats['total_workouts'] as int? ?? 0;
    final vo2 = (keyMetricsAttia['estimated_vo2'] as num?)?.toDouble() ?? 0;
    final zone2Weekly = (keyMetricsAttia['zone2_volume_weekly_avg'] as num?)?.toInt() ?? 0;

    final sb = StringBuffer();
    sb.writeln('=== PROFILO FITNESS AI-READY (FitAI Analyzer) ===');
    sb.writeln();
    sb.writeln('OBIETTIVO: $goalIa');
    sb.writeln();
    sb.writeln('--- STATISTICHE ANNUALI $year ---');
    sb.writeln('Distanza totale: ${totalKm.toStringAsFixed(1)} km');
    sb.writeln('Allenamenti totali: $workouts');
    final avgKcal = annualStats['avg_daily_kcal'] as num?;
    final avgProtein = annualStats['avg_daily_protein'] as num?;
    final avgLongevity = annualStats['avg_longevity_score'] as num?;
    if (avgKcal != null || avgProtein != null) {
      sb.writeln('Nutrizione media giornaliera: ${avgKcal?.toStringAsFixed(0) ?? '?'} kcal, ${avgProtein?.toStringAsFixed(0) ?? '?'} g proteine');
      if (avgLongevity != null) sb.writeln('Score longevità medio: ${avgLongevity.toStringAsFixed(1)}/10');
    }
    sb.writeln();
    sb.writeln('--- METRICHE LONGEVITÀ (riferimenti Peter Attia, Outlive) ---');
    sb.writeln('VO2max stimato: ${vo2.toStringAsFixed(1)} ml/kg/min');
    sb.writeln('Volume Zone 2 settimanale medio: $zone2Weekly minuti');
    sb.writeln('Zone 2 (60-70% max HR) è fondamentale per salute mitocondriale e longevità.');
    sb.writeln();
    sb.writeln('--- ULTIMI 10 GIORNI ---');
    sb.writeln('Distanza: ${rolling.totalDistanceKm.toStringAsFixed(1)} km');
    sb.writeln('Zone 2 totale: ${rolling.totalZone2Minutes} min');
    sb.writeln('FC media: ${rolling.avgHr.toStringAsFixed(0)} bpm');
    sb.writeln();
    sb.writeln('--- TREND MENSILI ---');
    for (final m in monthlyTrends) {
      final km = (m['total_km'] as num?)?.toDouble() ?? 0;
      final w = m['workouts'] as int? ?? 0;
      final mKcal = m['avg_kcal'] as num?;
      final mProt = m['avg_protein'] as num?;
      final nutStr = (mKcal != null || mProt != null)
          ? ' | Nut: ${mKcal?.toStringAsFixed(0) ?? '?'} kcal, ${mProt?.toStringAsFixed(0) ?? '?'}g prot'
          : '';
      sb.writeln('Mese ${m['month']}: $km km, $w allenamenti$nutStr');
    }
    sb.writeln();
    sb.writeln('--- EVOLUZIONE ---');
    sb.writeln(evolutionNotes);
    sb.writeln();
    sb.writeln('--- RIFERIMENTI ---');
    sb.writeln('Peter Attia, Outlive: Zone 2, VO2max, forza, composizione corporea.');
    sb.writeln('Studi Stanford: correlazione VO2max e mortalità.');

    return sb.toString();
  }
}
