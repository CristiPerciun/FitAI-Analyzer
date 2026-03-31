import 'package:fitai_analyzer/models/home_longevity_plan_day.dart';
import 'package:fitai_analyzer/providers/data_sync_notifier.dart';
import 'package:fitai_analyzer/providers/providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Metriche del giorno corrente condivise tra Home, Alimentazione e altre schermate.
class TodayLongevityMetrics {
  const TodayLongevityMetrics({
    this.steps = 0,
    this.caloriesBurned = 0,
    this.caloriesIntake = 0,
  });

  final double steps;
  final double caloriesBurned;
  final double caloriesIntake;
}

/// Passi da `daily_health`, calorie bruciate da `activities` con fallback su
/// `daily_logs.total_burned` (pacchetto Home), calorie assunte da `nutritionForAi`.
final todayLongevityMetricsProvider = Provider<TodayLongevityMetrics>((ref) {
  final todayStr = localCalendarDateKey();
  final package = ref.watch(longevityHomePackageProvider).valueOrNull;
  final activities = ref.watch(activitiesStreamProvider).valueOrNull ?? [];
  final dailyHealth = ref.watch(dailyHealthStreamProvider).valueOrNull ?? [];

  final todayActivities = activities.where((d) {
    final key =
        '${d.date.year}-${d.date.month.toString().padLeft(2, '0')}-${d.date.day.toString().padLeft(2, '0')}';
    return key == todayStr;
  }).toList();

  double steps = 0;
  Map<String, dynamic>? todayDailyHealth;
  for (final d in dailyHealth) {
    if ((d['date'] as String?) == todayStr) {
      todayDailyHealth = d;
      break;
    }
  }
  if (todayDailyHealth != null) {
    final stats = todayDailyHealth['stats'] as Map<String, dynamic>?;
    if (stats != null) {
      final s = stats['totalSteps'] ?? stats['userSteps'];
      if (s != null) steps = (s as num).toDouble();
    }
  }

  final caloriesFromActivities = todayActivities.fold<double>(
    0,
    (s, d) => s + (d.calories ?? 0),
  );

  final caloriesBurned = caloriesFromActivities > 0
      ? caloriesFromActivities
      : (package?.today?.totalBurnedKcalForAggregation ?? 0);

  double caloriesIntake = 0;
  final todayNut = package?.today?.nutritionForAi;
  if (todayNut != null && todayNut.isNotEmpty) {
    final cal = todayNut['total_calories'] ?? todayNut['total_kcal'];
    caloriesIntake = (cal as num?)?.toDouble() ?? 0;
  }

  return TodayLongevityMetrics(
    steps: steps,
    caloriesBurned: caloriesBurned,
    caloriesIntake: caloriesIntake,
  );
});
