import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/baseline_profile_model.dart';
import '../models/daily_log_model.dart';
import '../models/rolling_10days_model.dart';
import '../models/user_profile.dart';
import 'nutrition_calculator_service.dart';
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

  // ==================== HELPER STATICI ====================
  static double _actDistanceM(Map<String, dynamic> act) {
    final distanceKm = (act['distanceKm'] as num?)?.toDouble();
    if (distanceKm != null && distanceKm > 0) return distanceKm * 1000;
    final d = (act['distance'] as num?)?.toDouble() ?? 0;
    if (d > 0 && d < 100) return d * 1000;
    return d;
  }

  static int _actElapsedSec(Map<String, dynamic> act) {
    final elapsedMinutes = (act['elapsedMinutes'] as num?)?.toDouble();
    if (elapsedMinutes != null && elapsedMinutes > 0) {
      return (elapsedMinutes * 60).round();
    }
    final activeMinutes = (act['activeMinutes'] as num?)?.toDouble();
    if (activeMinutes != null && activeMinutes > 0) {
      return (activeMinutes * 60).round();
    }
    final e = act['elapsed_time'] ?? act['moving_time'];
    if (e != null) return (e as num).toInt();
    final d = act['duration'] ?? act['movingDuration'];
    return (d as num?)?.toInt() ?? 0;
  }

  static double? _actAvgHr(Map<String, dynamic> act) {
    final v = act['avgHeartrate'] ??
        act['average_heartrate'] ??
        act['averageHR'] ??
        act['averageHeartRate'];
    return (v as num?)?.toDouble();
  }

  static double? _actMaxHr(Map<String, dynamic> act) {
    final v = act['maxHeartrate'] ??
        act['max_heartrate'] ??
        act['maxHR'] ??
        act['maxHeartRate'];
    return (v as num?)?.toDouble();
  }

  static String _actSportType(Map<String, dynamic> act) {
    final unified = act['activityType'];
    if (unified != null) return unified.toString().toLowerCase();
    final t = act['sport_type'] ?? act['type'];
    if (t != null) return t.toString().toLowerCase();
    final tk = act['activityTypeKey']?.toString();
    if (tk != null && tk.isNotEmpty) return tk.toLowerCase();
    final g = act['activityType'];
    if (g is Map) {
      return ((g['typeKey'] ?? g['typeId'])?.toString() ?? '').toLowerCase();
    }
    return (g?.toString() ?? '').toLowerCase();
  }

  static double? _extractHealthVo2Max(Map<String, dynamic> health) {
    final maxMetrics = health['max_metrics'] as Map<String, dynamic>?;
    final stats = health['stats'] as Map<String, dynamic>?;
    final value = maxMetrics?['vo2Max'] ?? maxMetrics?['maxVo2'] ?? stats?['vo2Max'];
    return (value as num?)?.toDouble();
  }

  static double? _extractFitnessAge(Map<String, dynamic> health) {
    final fitnessAge = health['fitness_age'] as Map<String, dynamic>?;
    final value = fitnessAge?['fitnessAge'] ?? fitnessAge?['age'];
    return (value as num?)?.toDouble();
  }

  static DailyLogModel _dailyLogFromDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    return DailyLogModel.fromJson({
      ...data,
      'date': doc.id,
      'goal_today_ia': data['goal_today_ia'] ?? data['goal_today'] ?? '',
      'timestamp': data['timestamp'] ?? Timestamp.now(),
    });
  }

  // ==================== RECUPERO DATI ====================
  Future<Map<String, List<Map<String, dynamic>>>> _getActivitiesRange({
    required FirebaseFirestore firestore,
    required String uid,
    required String startDate,
    required String endDate,
  }) async {
    final snapshot = await firestore
        .collection('users')
        .doc(uid)
        .collection('activities')
        .where('dateKey', isGreaterThanOrEqualTo: startDate)
        .where('dateKey', isLessThanOrEqualTo: endDate)
        .get();

    final byDate = <String, List<Map<String, dynamic>>>{};
    for (final doc in snapshot.docs) {
      final data = doc.data();
      final dateKey = data['dateKey']?.toString();
      if (dateKey == null || dateKey.isEmpty) continue;
      byDate.putIfAbsent(dateKey, () => []).add({'id': doc.id, ...data});
    }
    return byDate;
  }

  Future<Map<String, Map<String, dynamic>>> _getDailyHealthRange({
    required FirebaseFirestore firestore,
    required String uid,
    required String startDate,
    required String endDate,
  }) async {
    final snapshot = await firestore
        .collection('users')
        .doc(uid)
        .collection('daily_health')
        .where(FieldPath.documentId, isGreaterThanOrEqualTo: startDate)
        .where(FieldPath.documentId, isLessThanOrEqualTo: endDate)
        .get();

    return {
      for (final doc in snapshot.docs) doc.id: {...doc.data(), 'date': doc.id},
    };
  }

  // ==================== AGGIORNAMENTO PRINCIPALE ====================
  Future<void> updateRolling10DaysAndBaseline(String uid) async {
    final firestore = FirebaseFirestore.instance;
    final dailyLogsRef = firestore
        .collection('users')
        .doc(uid)
        .collection('daily_logs');

    final today = DateTime.now();
    final tenDaysAgo = today.subtract(const Duration(days: 10));
    final startDateStr = tenDaysAgo.toIso8601String().split('T')[0];
    final endDateStr = today.toIso8601String().split('T')[0];

    final snapshot = await dailyLogsRef
        .where(FieldPath.documentId, isGreaterThanOrEqualTo: startDateStr)
        .where(FieldPath.documentId, isLessThanOrEqualTo: endDateStr)
        .get();

    final docs = snapshot.docs.toList()..sort((a, b) => b.id.compareTo(a.id));
    final dailyLogs = docs.take(10).map(_dailyLogFromDoc).toList();
    dailyLogs.sort((a, b) => a.date.compareTo(b.date));

    final activitiesByDate = await _getActivitiesRange(
      firestore: firestore,
      uid: uid,
      startDate: startDateStr,
      endDate: endDateStr,
    );

    final dailyHealthByDate = await _getDailyHealthRange(
      firestore: firestore,
      uid: uid,
      startDate: startDateStr,
      endDate: endDateStr,
    );

    final rolling = _computeRolling10Days(
      dailyLogs,
      activitiesByDate: activitiesByDate,
      dailyHealthByDate: dailyHealthByDate,
    );

    await firestore
        .collection('users')
        .doc(uid)
        .collection('rolling_10days')
        .doc('current')
        .set(rolling.toJson());

    final baselineRef = firestore
        .collection('users')
        .doc(uid)
        .collection('profile')
        .doc('baseline');

    final baselineDoc = await baselineRef.get();
    final lastBaseline = baselineDoc.exists
        ? (baselineDoc.data()?['last_baseline_update'] as Timestamp?)?.toDate()
        : null;

    final shouldUpdateBaseline = lastBaseline == null ||
        today.difference(lastBaseline).inDays >= _baselineUpdateIntervalDays;

    if (shouldUpdateBaseline) {
      final baseline = await _computeBaselineProfile(
        uid: uid,
        firestore: firestore,
        rolling: rolling,
      );
      await baselineRef.set(baseline.toJson());
    }
  }

  // ==================== COMPUTE ROLLING 10 DAYS ====================
  Rolling10DaysModel _computeRolling10Days(
    List<DailyLogModel> dailyLogs, {
    required Map<String, List<Map<String, dynamic>>> activitiesByDate,
    required Map<String, Map<String, dynamic>> dailyHealthByDate,
  }) {
    double totalDistanceKm = 0;
    int totalZone2Minutes = 0;
    double sumHr = 0;
    int hrCount = 0;
    double? bestVo2FromPace;
    double? latestHealthVo2;

    final activitiesSummary = <Map<String, dynamic>>[];
    final macroSums = <String, double>{
      'protein_g': 0,
      'carbs_g': 0,
      'fat_g': 0,
      'calories': 0,
    };
    int macroDays = 0;

    for (final log in dailyLogs) {
      double dayDistance = 0;
      int dayZone2Min = 0;

      final activities = activitiesByDate[log.date] ?? const [];
      for (final act in activities) {
        final distM = _actDistanceM(act);
        final distKm = distM / 1000;
        dayDistance += distKm;

        final elapsedSec = _actElapsedSec(act);
        final elapsedMin = elapsedSec / 60;

        final avgHr = _actAvgHr(act);
        final maxHr = _actMaxHr(act);

        if (avgHr != null) {
          sumHr += avgHr;
          hrCount++;
        }

        final maxForZone2 = maxHr ?? 180;
        final zone2Low = maxForZone2 * 0.60;
        final zone2High = maxForZone2 * 0.70;

        if (avgHr != null && avgHr >= zone2Low && avgHr <= zone2High) {
          dayZone2Min += elapsedMin.round();
        } else if (avgHr != null && avgHr < zone2High) {
          dayZone2Min += (elapsedMin * 0.5).round();
        }
      }

      totalDistanceKm += dayDistance;
      totalZone2Minutes += dayZone2Min;

      for (final act in activities) {
        final sport = _actSportType(act);
        if (sport.contains('run')) {
          final distM = _actDistanceM(act);
          final movingSec = _actElapsedSec(act);
          if (distM > 0 && movingSec > 0) {
            final paceMinPerKm = (movingSec / 60) / (distM / 1000);
            final vo2 = 2.8 + (3.5 * 1000 / (paceMinPerKm * 60));
            if (bestVo2FromPace == null || vo2 > bestVo2FromPace) {
              bestVo2FromPace = vo2;
            }
          }
        }
      }

      final health = dailyHealthByDate[log.date];
      final healthVo2 = health != null ? _extractHealthVo2Max(health) : null;
      if (healthVo2 != null) latestHealthVo2 = healthVo2;

      activitiesSummary.add({
        'date': log.date,
        'distance_km': dayDistance,
        'zone2_minutes': dayZone2Min,
        'total_burned_kcal': log.totalBurnedKcalForAggregation,
      });

      final nut = log.nutritionForAi;
      if (nut.isNotEmpty) {
        macroDays++;
        macroSums['protein_g'] = macroSums['protein_g']! + (nut['protein_g'] as num? ?? 0).toDouble();
        macroSums['carbs_g']   = macroSums['carbs_g']!   + (nut['carbs_g'] as num? ?? 0).toDouble();
        macroSums['fat_g']     = macroSums['fat_g']!     + (nut['fat_g'] as num? ?? 0).toDouble();
        macroSums['calories']  = macroSums['calories']!  + (nut['total_calories'] as num? ?? 0).toDouble();
      }
    }

    final avgHr = hrCount > 0 ? sumHr / hrCount : 0.0;
    final estimatedVo2 = latestHealthVo2 ?? bestVo2FromPace ?? 35.0 + (totalDistanceKm / 10);

    final macroAverages = <String, double>{};
    if (macroDays > 0) {
      macroAverages['protein_g'] = macroSums['protein_g']! / macroDays;
      macroAverages['carbs_g']   = macroSums['carbs_g']!   / macroDays;
      macroAverages['fat_g']     = macroSums['fat_g']!     / macroDays;
      macroAverages['calories']  = macroSums['calories']!  / macroDays;
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

  // ==================== COMPUTE BASELINE PROFILE ====================
  Future<BaselineProfileModel> _computeBaselineProfile({
    required String uid,
    required FirebaseFirestore firestore,
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

    final allLogs = snapshot.docs.map(_dailyLogFromDoc).toList();
    allLogs.sort((a, b) => a.date.compareTo(b.date));

    final activitiesByDate = await _getActivitiesRange(
      firestore: firestore,
      uid: uid,
      startDate: startOfYear,
      endDate: todayStr,
    );
    final dailyHealthByDate = await _getDailyHealthRange(
      firestore: firestore,
      uid: uid,
      startDate: startOfYear,
      endDate: todayStr,
    );

    UserProfile? userProfile;
    try {
      final profileDoc = await firestore
          .collection('users')
          .doc(uid)
          .collection('profile')
          .doc('profile')
          .get();
      if (profileDoc.exists && profileDoc.data() != null) {
        userProfile = UserProfile.fromJson(profileDoc.data()!);
      }
    } catch (_) {}

    NutritionEnergyResult? nutritionEnergy;
    if (userProfile != null && userProfile.nutritionGoal != null) {
      nutritionEnergy = NutritionCalculatorService.computeFromUserProfile(userProfile);
    }

    String goalIa = '';
    final goalCounts = <String, int>{};
    for (final log in allLogs) {
      final g = log.goalTodayIa;
      if (g.isNotEmpty) goalCounts[g] = (goalCounts[g] ?? 0) + 1;
    }
    if (goalCounts.isNotEmpty) {
      goalIa = goalCounts.entries.reduce((a, b) => a.value > b.value ? a : b).key;
    }

    double totalKm = 0;
    int totalWorkouts = 0;
    double weightSum = 0;
    int weightCount = 0;
    double nutritionKcalSum = 0;
    double nutritionProteinSum = 0;
    double nutritionLongevitySum = 0;
    int nutritionDaysCount = 0;
    double? latestVo2Max;
    double? latestFitnessAge;

    for (final log in allLogs) {
      for (final act in (activitiesByDate[log.date] ?? const [])) {
        totalKm += _actDistanceM(act) / 1000;
        totalWorkouts++;
      }

      final health = dailyHealthByDate[log.date];
      final healthVo2 = health != null ? _extractHealthVo2Max(health) : null;
      final healthFitnessAge = health != null ? _extractFitnessAge(health) : null;
      if (healthVo2 != null) latestVo2Max = healthVo2;
      if (healthFitnessAge != null) latestFitnessAge = healthFitnessAge;

      if (log.weightKg != null) {
        weightSum += log.weightKg!;
        weightCount++;
      }

      final nut = log.nutritionForAi;
      if (nut.isNotEmpty) {
        nutritionDaysCount++;
        nutritionKcalSum += (nut['total_calories'] as num? ?? 0).toDouble();
        nutritionProteinSum += (nut['protein_g'] as num? ?? 0).toDouble();
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
      'latest_vo2max': latestVo2Max,
      'latest_fitness_age': latestFitnessAge,
    };

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
        for (final act in (activitiesByDate[log.date] ?? const [])) {
          mKm += _actDistanceM(act) / 1000;
          mWorkouts++;
        }

        final nut = log.nutritionForAi;
        if (nut.isNotEmpty) {
          mNutDays++;
          mKcal += (nut['total_calories'] as num? ?? 0).toDouble();
          mProtein += (nut['protein_g'] as num? ?? 0).toDouble();
          final longevity = nut['avg_longevity_score'];
          if (longevity != null) {
            mLongevity += (double.tryParse(longevity.toString()) ?? 0);
          }
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

    final zone2Weekly = (rolling.totalZone2Minutes / 10) * 7;
    final keyMetricsAttia = <String, dynamic>{
      'estimated_vo2': latestVo2Max ?? rolling.estimatedVo2Max,
      'zone2_volume_weekly_avg': zone2Weekly.round(),
      'strength_score': 75,
      'visceral_fat_estimate': 'basso',
      'hr_recovery_avg': 45,
      'fitness_age': latestFitnessAge,
    };

    String evolutionNotes = _buildEvolutionNotes(
      allLogs: allLogs,
      annualStats: annualStats,
      year: year,
    );

    String aiReadySummary = _buildAiReadySummary(
      goalIa: goalIa,
      annualStats: annualStats,
      keyMetricsAttia: keyMetricsAttia,
      monthlyTrends: monthlyTrends,
      evolutionNotes: evolutionNotes,
      rolling: rolling,
    );

    double? bmrKcal = nutritionEnergy?.bmrKcal;
    double? tdeeKcal = nutritionEnergy?.tdeeKcal;
    double? activityMult = nutritionEnergy?.activityMultiplier;
    String? activityLevelDerived = nutritionEnergy?.activityLevel;
    double? nutritionCalTarget = nutritionEnergy?.calorieTarget;
    double? nutritionAdjFrac = nutritionEnergy?.adjustmentFraction;
    Map<String, dynamic>? nutritionSnap = userProfile?.nutritionGoal?.toJson();

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
      bmrKcal: bmrKcal,
      tdeeKcal: tdeeKcal,
      activityMultiplier: activityMult,
      activityLevelDerived: activityLevelDerived,
      nutritionCalorieTarget: nutritionCalTarget,
      nutritionEnergyAdjustmentFraction: nutritionAdjFrac,
      nutritionGoalSnapshot: nutritionSnap,
    );
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
      sb.writeln(
        'Nutrizione media giornaliera: ${avgKcal?.toStringAsFixed(0) ?? '?'} kcal, ${avgProtein?.toStringAsFixed(0) ?? '?'} g proteine',
      );
      if (avgLongevity != null) {
        sb.writeln('Score longevità medio: ${avgLongevity.toStringAsFixed(1)}/10');
      }
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