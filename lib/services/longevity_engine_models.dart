part of 'longevity_engine.dart';

/// Contesto unificato per il prompt giornaliero.
/// Combina il ricco contesto storico (2 mesi, 7 giorni, baseline) con i dati
/// più recenti (ieri specifico, rolling 10 giorni) e il diario evolutivo.
class UnifiedDailyContext {
  final UserProfile? userProfile;
  final String yesterdayDate;
  final String todayDate;

  /// Dati di ieri: estratti dall'elemento 0 di [detailed7Days].
  final DailyLogModel? yesterdayLog;
  final List<Map<String, dynamic>> yesterdayActivities;
  final Map<String, dynamic>? yesterdayHealth;

  /// Rolling aggregato 10 giorni.
  final Rolling10DaysModel? rolling;

  /// Diario evoluzione utente (da profile/diary).
  final String longevityDiary;

  /// Profilo baseline annuale (da profile/baseline).
  final BaselineProfileModel? baseline;

  /// Ultimi 7 giorni in dettaglio (attività + biometrici).
  final List<DayDetail> detailed7Days;

  /// Medie settimanali ultimi 2 mesi.
  final List<WeeklySummary> weekly2Months;

  /// Piano `ai_current/allenamenti` già salvato per [todayDate] (se esiste).
  final AiCurrentAllenamentiModel? existingAllenamentiForToday;

  const UnifiedDailyContext({
    this.userProfile,
    required this.yesterdayDate,
    required this.todayDate,
    this.yesterdayLog,
    this.yesterdayActivities = const [],
    this.yesterdayHealth,
    this.rolling,
    this.longevityDiary = '',
    this.baseline,
    this.detailed7Days = const [],
    this.weekly2Months = const [],
    this.existingAllenamentiForToday,
  });
}

/// Contesto completo per prompt Gemini: profilo + 2 mesi + 7 giorni + note + diario longevità.
class GeminiHomeContext {
  final UserProfile? userProfile;
  final List<DayDetail> detailed7Days;
  final List<WeeklySummary> weeklySummary;
  final BaselineProfileModel? baseline;

  /// Diario della Longevità precedente (da profile/diary) per aggiornare lo storico.
  final String longevityDiary;

  const GeminiHomeContext({
    this.userProfile,
    required this.detailed7Days,
    required this.weeklySummary,
    this.baseline,
    this.longevityDiary = '',
  });
}

/// Dettaglio di un singolo giorno (attività + daily_health).
class DayDetail {
  final String date;
  final DailyLogModel? log;
  final List<Map<String, dynamic>> activities;
  final Map<String, dynamic>? health;

  const DayDetail({
    required this.date,
    this.log,
    this.activities = const [],
    this.health,
  });
}

/// Riepilogo settimanale aggregato (medie/ totali per settimana).
class WeeklySummary {
  final String weekStart;
  final double totalDistanceKm;
  final int totalWorkouts;
  final double avgSteps;
  final double? avgSleepScore;
  final double avgCalories;
  final double? vo2Max;
  final double? fitnessAge;

  const WeeklySummary({
    required this.weekStart,
    required this.totalDistanceKm,
    required this.totalWorkouts,
    required this.avgSteps,
    this.avgSleepScore,
    required this.avgCalories,
    this.vo2Max,
    this.fitnessAge,
  });
}

class _WeekAccumulator {
  final distances = <double>[];
  int workouts = 0;
  final steps = <double>[];
  final sleepScores = <double>[];
  final calories = <double>[];
  double? latestVo2Max;
  double? latestFitnessAge;

  void addNutrition(DailyLogModel log) {
    final nut = log.nutritionForAi;
    final cal = nut['total_calories'] ?? nut['total_kcal'];
    if (cal != null) calories.add((cal as num).toDouble());
  }

  void addActivities(List<Map<String, dynamic>> acts) {
    workouts += acts.length;
    for (final a in acts) {
      final distanceKm = (a['distanceKm'] as num?)?.toDouble();
      final legacyDistance = (a['distance'] as num?)?.toDouble();
      final meters = distanceKm != null && distanceKm > 0
          ? distanceKm * 1000
          : legacyDistance != null && legacyDistance > 0
          ? (legacyDistance < 100 ? legacyDistance * 1000 : legacyDistance)
          : null;
      if (meters != null && meters > 0) distances.add(meters);
    }
  }

  void addHealth(Map<String, dynamic> h) {
    final stats = h['stats'] as Map<String, dynamic>?;
    if (stats != null) {
      final s = stats['totalSteps'] ?? stats['userSteps'];
      if (s != null) steps.add((s as num).toDouble());
    }
    final sleep = h['sleep'] as Map<String, dynamic>?;
    if (sleep != null) {
      final score = sleep['sleepScore'] ?? sleep['overallSleepScore'];
      if (score != null) sleepScores.add((score as num).toDouble());
    }
    final maxMetrics = h['max_metrics'] as Map<String, dynamic>?;
    if (maxMetrics != null) {
      final v =
          maxMetrics['vo2Max'] ?? maxMetrics['maxVo2'] ?? stats?['vo2Max'];
      if (v != null) latestVo2Max = (v as num).toDouble();
    }
    final fitnessAge = h['fitness_age'] as Map<String, dynamic>?;
    if (fitnessAge != null) {
      final fa = fitnessAge['fitnessAge'] ?? fitnessAge['age'];
      if (fa != null) latestFitnessAge = (fa as num).toDouble();
    }
  }

  WeeklySummary toSummary(String weekStart) {
    final distKm = distances.isEmpty
        ? 0.0
        : distances.reduce((a, b) => a + b) / 1000;
    final avgSteps = steps.isEmpty
        ? 0.0
        : steps.reduce((a, b) => a + b) / steps.length;
    final avgSleep = sleepScores.isEmpty
        ? null
        : sleepScores.reduce((a, b) => a + b) / sleepScores.length;
    final avgCal = calories.isEmpty
        ? 0.0
        : calories.reduce((a, b) => a + b) / calories.length;
    return WeeklySummary(
      weekStart: weekStart,
      totalDistanceKm: distKm,
      totalWorkouts: workouts,
      avgSteps: avgSteps,
      avgSleepScore: avgSleep,
      avgCalories: avgCal,
      vo2Max: latestVo2Max,
      fitnessAge: latestFitnessAge,
    );
  }
}
