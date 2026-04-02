import 'package:fitai_analyzer/models/fitness_data.dart';
import 'package:fitai_analyzer/providers/data_sync_notifier.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Filtro data elenco allenamenti: null = oggi, dateFilterAll = tutti, altrimenti YYYY-MM-DD.
final selectedDateFilterProvider = StateProvider<String?>((ref) => null);

String activityDateKey(DateTime d) {
  final m = d.month.toString().padLeft(2, '0');
  final day = d.day.toString().padLeft(2, '0');
  return '${d.year}-$m-$day';
}

enum ActivityBurnChartMode { week, month }

/// Mese mostrato nel calendario (e usato dal grafico in modalità mensile).
final dashboardCalendarMonthProvider =
    StateProvider<DateTime>((ref) {
  final n = DateTime.now();
  return DateTime(n.year, n.month);
});

final activityBurnChartModeProvider =
    StateProvider<ActivityBurnChartMode>(
  (ref) => ActivityBurnChartMode.week,
);

double _sumKcal(List<FitnessData> list) {
  return list.fold<double>(
    0,
    (s, a) => s + (a.calories ?? 0),
  );
}

class ActivityBurnBarPoint {
  final String label;
  final double kcal;

  const ActivityBurnBarPoint(this.label, this.kcal);
}

/// Serie per fl_chart: ultimi 7 giorni o ogni giorno del mese corrente in [dashboardCalendarMonthProvider].
final activityBurnChartPointsProvider =
    Provider<List<ActivityBurnBarPoint>>((ref) {
  final byDate = ref.watch(activitiesByDateProvider);
  final mode = ref.watch(activityBurnChartModeProvider);
  final month = ref.watch(dashboardCalendarMonthProvider);
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);

  if (mode == ActivityBurnChartMode.week) {
    const italianShort = ['Lu', 'Ma', 'Me', 'Gio', 'Ve', 'Sa', 'Do'];
    final out = <ActivityBurnBarPoint>[];
    for (var i = 6; i >= 0; i--) {
      final d = today.subtract(Duration(days: i));
      final key = activityDateKey(d);
      final kcal = _sumKcal(byDate[key] ?? []);
      out.add(ActivityBurnBarPoint(italianShort[d.weekday - 1], kcal));
    }
    return out;
  }

  final last = DateTime(month.year, month.month + 1, 0);
  final out = <ActivityBurnBarPoint>[];
  for (var day = 1; day <= last.day; day++) {
    final d = DateTime(month.year, month.month, day);
    final key = activityDateKey(d);
    final kcal = _sumKcal(byDate[key] ?? []);
    out.add(ActivityBurnBarPoint('$day', kcal));
  }
  return out;
});
