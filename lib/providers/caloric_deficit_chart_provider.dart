import 'package:fitai_analyzer/models/fitness_data.dart';
import 'package:fitai_analyzer/models/user_profile.dart';
import 'package:fitai_analyzer/providers/data_sync_notifier.dart';
import 'package:fitai_analyzer/providers/nutrition_chart_provider.dart';
import 'package:fitai_analyzer/providers/providers.dart'
    show nutritionMealPlanAiStreamProvider;
import 'package:fitai_analyzer/providers/user_profile_notifier.dart';
import 'package:fitai_analyzer/services/nutrition_calculator_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

String _dateKey(DateTime d) {
  final m = d.month.toString().padLeft(2, '0');
  final day = d.day.toString().padLeft(2, '0');
  return '${d.year}-$m-$day';
}

DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

DateTime _mondayOfWeekContaining(DateTime day) {
  final d = _dateOnly(day);
  return d.subtract(Duration(days: d.weekday - 1));
}

DateTime _weekMondayForOffset(int weekOffset) {
  final today = _dateOnly(DateTime.now());
  final thisWeekMonday = _mondayOfWeekContaining(today);
  return thisWeekMonday.subtract(Duration(days: 7 * weekOffset));
}

double _sumActivityKcal(List<FitnessData> list) {
  return list.fold<double>(0, (s, a) => s + (a.calories ?? 0));
}

double? _macroNum(Map<String, dynamic>? m, List<String> keys) {
  if (m == null) return null;
  for (final k in keys) {
    final v = m[k];
    if (v is num) return v.toDouble();
    final parsed = double.tryParse(v?.toString() ?? '');
    if (parsed != null) return parsed;
  }
  return null;
}

/// Punto giornaliero per il grafico bilancio calorico.
class CaloricDeficitDayPoint {
  const CaloricDeficitDayPoint({
    required this.label,
    required this.dateKey,
    required this.intakeKcal,
    required this.activityBurnKcal,
    required this.dynamicTdeeKcal,
    required this.thresholdKcal,
    required this.moderateCeilingKcal,
    required this.aggressiveCeilingKcal,
    required this.surplusKcal,
    required this.isInDeficit,
    required this.isToday,
  });

  final String label;
  final String dateKey;
  final double intakeKcal;
  final double activityBurnKcal;
  final double dynamicTdeeKcal;
  /// Obiettivo giornaliero (target profilo + attività registrata).
  final double thresholdKcal;
  final double moderateCeilingKcal;
  final double aggressiveCeilingKcal;
  final double surplusKcal;
  final bool isInDeficit;
  final bool isToday;
}

/// Dati settimanali per [CaloricDeficitBarChartCard].
class CaloricDeficitWeekChartData {
  const CaloricDeficitWeekChartData({
    required this.weekOffset,
    required this.points,
    required this.staticTdeeKcal,
    required this.bmrKcal,
    required this.calorieTargetKcal,
    required this.deficitKcal,
    required this.showDeficitBands,
    required this.todayStatusText,
  });

  final int weekOffset;
  final List<CaloricDeficitDayPoint> points;
  final double staticTdeeKcal;
  final double bmrKcal;
  final double calorieTargetKcal;
  final double deficitKcal;
  final bool showDeficitBands;
  final String? todayStatusText;

  factory CaloricDeficitWeekChartData.empty({int weekOffset = 0}) {
    final weekMonday = _weekMondayForOffset(weekOffset);
    const labels = ['Lu', 'Ma', 'Me', 'Gio', 'Ve', 'Sa', 'Do'];
    final todayKey = _dateKey(_dateOnly(DateTime.now()));
    final points = List.generate(7, (i) {
      final d = weekMonday.add(Duration(days: i));
      final key = _dateKey(d);
      return CaloricDeficitDayPoint(
        label: labels[i],
        dateKey: key,
        intakeKcal: 0,
        activityBurnKcal: 0,
        dynamicTdeeKcal: 0,
        thresholdKcal: 0,
        moderateCeilingKcal: 0,
        aggressiveCeilingKcal: 0,
        surplusKcal: 0,
        isInDeficit: false,
        isToday: key == todayKey,
      );
    });
    return CaloricDeficitWeekChartData(
      weekOffset: weekOffset,
      points: points,
      staticTdeeKcal: 0,
      bmrKcal: 0,
      calorieTargetKcal: 0,
      deficitKcal: 0,
      showDeficitBands: false,
      todayStatusText: null,
    );
  }
}

CaloricDeficitWeekChartData _buildFromInputs({
  required int weekOffset,
  required NutritionChartData chartData,
  required Map<String, List<FitnessData>> activitiesByDate,
  required UserProfile? profile,
  required double? aiCalorieTarget,
}) {
  if (profile == null) {
    return CaloricDeficitWeekChartData.empty(weekOffset: weekOffset);
  }

  final energy = NutritionCalculatorService.computeFromUserProfile(profile);
  final bmr = energy.bmrKcal;
  final staticTdee = energy.tdeeKcal;
  final ng = profile.nutritionGoal;
  final showBands = ng != null &&
      NutritionCalculatorService.isWeightLossObjective(ng.nutritionObjective);
  final calorieTarget =
      (aiCalorieTarget != null && aiCalorieTarget > 0)
          ? aiCalorieTarget
          : energy.calorieTarget;
  final deficitKcal =
      ng == null ? 0.0 : (staticTdee - calorieTarget).clamp(0.0, double.infinity);

  final weekMonday = _weekMondayForOffset(weekOffset);
  final todayKey = _dateKey(_dateOnly(DateTime.now()));
  final points = <CaloricDeficitDayPoint>[];

  for (var i = 0; i < 7; i++) {
    final d = weekMonday.add(Duration(days: i));
    final key = _dateKey(d);
    final intake = chartData.caloriesData[i].value;
    final burn = _sumActivityKcal(activitiesByDate[key] ?? []);
    final dynamicTdee = NutritionCalculatorService.dynamicTdeeKcal(
      tdeeKcal: staticTdee,
      activityBurnKcal: burn,
    );
    final threshold = ng == null
        ? dynamicTdee
        : NutritionCalculatorService.dailyCalorieCeilingKcal(
            calorieTarget: calorieTarget,
            activityBurnKcal: burn,
          );
    final moderateCeiling =
        NutritionCalculatorService.dynamicModerateCeilingKcal(
      tdeeKcal: staticTdee,
      activityBurnKcal: burn,
    );
    final aggressiveCeiling =
        NutritionCalculatorService.dynamicAggressiveCeilingKcal(
      tdeeKcal: staticTdee,
      activityBurnKcal: burn,
    );
    final surplus =
        intake > threshold ? intake - threshold : 0.0;
    final inDeficit = intake > 0 && intake <= threshold;

    points.add(
      CaloricDeficitDayPoint(
        label: chartData.caloriesData[i].day,
        dateKey: key,
        intakeKcal: intake,
        activityBurnKcal: burn,
        dynamicTdeeKcal: dynamicTdee,
        thresholdKcal: threshold,
        moderateCeilingKcal: moderateCeiling,
        aggressiveCeilingKcal: aggressiveCeiling,
        surplusKcal: surplus,
        isInDeficit: inDeficit,
        isToday: key == todayKey,
      ),
    );
  }

  String? todayStatus;
  CaloricDeficitDayPoint? todayPoint;
  for (final p in points) {
    if (p.isToday) {
      todayPoint = p;
      break;
    }
  }
  if (todayPoint != null && weekOffset == 0) {
    final p = todayPoint;
    if (p.intakeKcal <= 0) {
      todayStatus = 'Nessun pasto registrato oggi';
    } else if (p.isInDeficit) {
      final remaining = (p.thresholdKcal - p.intakeKcal).round();
      todayStatus = 'Oggi: in deficit ($remaining kcal sotto la soglia)';
    } else {
      todayStatus =
          'Oggi: sopra la soglia (+${p.surplusKcal.round()} kcal)';
    }
  }

  return CaloricDeficitWeekChartData(
    weekOffset: weekOffset,
    points: points,
    staticTdeeKcal: staticTdee,
    bmrKcal: bmr,
    calorieTargetKcal: calorieTarget,
    deficitKcal: deficitKcal,
    showDeficitBands: showBands,
    todayStatusText: todayStatus,
  );
}

/// Settimana ISO (lun–dom) per il grafico bilancio calorico su Alimentazione.
/// Provider sincrono: evita flicker del FutureProvider quando cambiano
/// activitiesStream / piano AI (ogni emit riavviava il future → spinner).
final caloricDeficitWeekChartProvider =
    Provider<CaloricDeficitWeekChartData>((ref) {
  final weekOffset = ref.watch(nutritionDiaryWeekOffsetProvider);
  final profile = ref.watch(userProfileNotifierProvider).profile;
  final plan = ref.watch(nutritionMealPlanAiStreamProvider).valueOrNull;
  final aiCalorieTarget =
      _macroNum(plan?.macroGiornalieri, ['kcal', 'calories']);
  final activitiesByDate = ref.watch(activitiesByDateProvider);
  final chartAsync = ref.watch(nutritionDiaryWeekChartDataProvider);
  final chartData = chartAsync.valueOrNull ??
      NutritionChartData.empty(weekOffset: weekOffset);

  return _buildFromInputs(
    weekOffset: weekOffset,
    chartData: chartData,
    activitiesByDate: activitiesByDate,
    profile: profile,
    aiCalorieTarget: aiCalorieTarget,
  );
});
