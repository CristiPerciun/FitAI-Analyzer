import 'package:fitai_analyzer/providers/dashboard_activity_providers.dart';
import 'package:fitai_analyzer/ui/widgets/design/design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Calorie bruciate per giorno, rese come grafico "equalizer/slider" del
/// redesign (traccia + porzione piena + pomello), stile schermata Statistics.
class ActivityBurnBarChartCard extends ConsumerWidget {
  const ActivityBurnBarChartCard({super.key});

  static double _maxY(List<ActivityBurnBarPoint> points) {
    final m = points
        .map((p) => p.kcal)
        .fold<double>(0, (a, b) => a > b ? a : b);
    return m <= 0 ? 1 : m;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(activityBurnChartModeProvider);
    final points = ref.watch(activityBurnChartPointsProvider);
    final maxY = _maxY(points);
    final isWeek = mode == ActivityBurnChartMode.week;

    // In modalità mese mostra solo le etichette di alcuni giorni.
    String labelFor(int i) {
      if (isWeek) return points[i].label;
      final day = i + 1;
      const milestones = {1, 5, 10, 15, 20, 25};
      if (milestones.contains(day) || day == points.length) {
        return points[i].label;
      }
      return '';
    }

    final bars = <FitSliderBar>[
      for (var i = 0; i < points.length; i++)
        FitSliderBar(
          (points[i].kcal / maxY).clamp(0.0, 1.0),
          labelFor(i),
          valueLabel: isWeek && points[i].kcal > 0
              ? points[i].kcal.toStringAsFixed(0)
              : null,
        ),
    ];

    return FitSoftCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const FitCardHeader(
            title: 'Calorie bruciate (attività)',
            subtitle: 'Dati da Strava / Garmin (Firestore)',
          ),
          const SizedBox(height: 14),
          FitSegmentedTabs(
            labels: const ['Settimana', 'Mese'],
            selectedIndex: isWeek ? 0 : 1,
            onChanged: (i) {
              ref.read(activityBurnChartModeProvider.notifier).state = i == 0
                  ? ActivityBurnChartMode.week
                  : ActivityBurnChartMode.month;
            },
          ),
          const SizedBox(height: 18),
          FitSliderBarChart(
            bars: bars,
            height: 200,
            trackWidth: isWeek ? 8 : 4,
            knobSize: isWeek ? 16 : 0,
            showValueLabels: isWeek,
          ),
        ],
      ),
    );
  }
}
