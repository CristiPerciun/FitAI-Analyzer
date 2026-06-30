import 'dart:ui';

import 'package:fitai_analyzer/models/meal_model.dart';
import 'package:fitai_analyzer/providers/today_longevity_metrics_provider.dart';
import 'package:fitai_analyzer/theme/app_card_theme.dart';
import 'package:fitai_analyzer/ui/widgets/anim_progress_ring.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Valore per oggi nella serie lun–dom (stesso ordine del fetch in `nutrition_chart_provider`: indice = `DateTime.weekday` − 1).
double _valueForTodayInIsoWeek(List<DailyNutrient> weeklyData) {
  if (weeklyData.isEmpty) return 0;
  final idx = DateTime.now().weekday - 1;
  if (idx < 0 || idx >= weeklyData.length) return 0;
  return weeklyData[idx].value;
}

class NutritionChartCard extends ConsumerStatefulWidget {
  // Passiamo la lista di tutti i goal per estrarre i dati di Carbi, Proteine e Grassi
  final List<NutrientGoal> allGoals;

  const NutritionChartCard({super.key, required this.allGoals});

  @override
  ConsumerState<NutritionChartCard> createState() => _NutritionChartCardState();
}

class _NutritionChartCardState extends ConsumerState<NutritionChartCard> {
  final PageController _pageController = PageController();
  final Set<String> _macroFullNotified = {};
  bool _macroCheckScheduled = false;

  // Helper per trovare il goal specifico nella lista del progetto
  NutrientGoal _getGoalByTitle(String titlePart) {
    return widget.allGoals.firstWhere(
      (g) => g.title.toLowerCase().contains(titlePart.toLowerCase()),
      orElse: () => widget.allGoals.first,
    );
  }

  @override
  Widget build(BuildContext context) {
    final metrics = ref.watch(todayLongevityMetricsProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Colori card adattativi al tema corrente (container natura in entrambi i temi).
    final cardBg = theme.colorScheme.surfaceContainerHighest;
    final cardBorder = isDark
        ? Colors.white.withValues(alpha: 0.05)
        : theme.colorScheme.outline.withValues(alpha: 0.15);
    final onCard = theme.colorScheme.onSurface;
    final onCardMuted = theme.colorScheme.onSurfaceVariant;
    final ringTrack = theme.colorScheme.onSurface.withValues(
      alpha: isDark ? 0.05 : 0.10,
    );
    final dotActive = theme.colorScheme.primary;
    final dotInactive = theme.colorScheme.onSurface.withValues(
      alpha: isDark ? 0.24 : 0.20,
    );
    final softShadow = theme.extension<AppCardTheme>()?.softShadow;

    // ESTRAZIONE DATI REALI DAL PROGETTO
    final calGoal = _getGoalByTitle("Calorie");
    final carbGoal = _getGoalByTitle("Carb");
    final protGoal = _getGoalByTitle("Prot");
    final fatGoal = _getGoalByTitle("Grass");

    // Calcolo valori reali
    double targetCal = calGoal.target;
    final foodCal = _valueForTodayInIsoWeek(calGoal.weeklyData);

    final double exercise = metrics.caloriesBurned;
    final double remainingCal = targetCal - foodCal + exercise;

    _scheduleMacroFullCheck();

    return Container(
      width: MediaQuery.of(context).size.width * 0.90,
      margin: const EdgeInsets.symmetric(vertical: 10),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: cardBorder),
        boxShadow: softShadow,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: 305,
            child: ScrollConfiguration(
              behavior: ScrollConfiguration.of(context).copyWith(
                dragDevices: {
                  PointerDeviceKind.touch,
                  PointerDeviceKind.mouse,
                  PointerDeviceKind.trackpad,
                },
              ),
              child: TickerMode(
                enabled: true,
                child: PageView(
                  clipBehavior: Clip.none,
                  controller: _pageController,
                  physics: const BouncingScrollPhysics(),
                  children: [
                    _buildTodayPage(
                      remainingCal,
                      targetCal,
                      foodCal,
                      exercise,
                      calGoal.color,
                      onCard: onCard,
                      onCardMuted: onCardMuted,
                      ringTrack: ringTrack,
                    ),
                    _buildMacrosPage(
                      carbGoal,
                      fatGoal,
                      protGoal,
                      onCard: onCard,
                      onCardMuted: onCardMuted,
                      ringTrack: ringTrack,
                    ),
                  ],
                ),
              ),
            ),
          ),

          const SizedBox(height: 15),

          // INDICATORE PUNTINI (guidato dal PageController, senza setState)
          AnimatedBuilder(
            animation: _pageController,
            builder: (context, _) {
              final page =
                  _pageController.hasClients && _pageController.page != null
                  ? _pageController.page!.round()
                  : 0;
              return Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  2,
                  (index) => _buildDot(index == page, dotActive, dotInactive),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildTodayPage(
    double rem,
    double target,
    double food,
    double ex,
    Color accentColor, {
    required Color onCard,
    required Color onCardMuted,
    required Color ringTrack,
  }) {
    final targetSafe = target <= 0 ? 1.0 : target;
    final foodProgress = (food / targetSafe).clamp(0.0, 1.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Today',
          style: TextStyle(
            color: onCard,
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          'Remaining = Goal - Food + Exercise',
          style: TextStyle(color: onCardMuted, fontSize: 11),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Stack(
              alignment: Alignment.center,
              children: [
                AnimProgressRing(
                  progress: foodProgress,
                  size: 152,
                  strokeWidth: 11,
                  accentColor: accentColor,
                  trackColor: ringTrack,
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${rem.toInt()}',
                      style: TextStyle(
                        color: onCard,
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Remaining',
                      style: TextStyle(color: onCardMuted, fontSize: 12),
                    ),
                  ],
                ),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _legendItem(
                  Icons.flag,
                  'Base Goal',
                  '${target.toInt()}',
                  onCardMuted,
                  onCard,
                ),
                const SizedBox(height: 16),
                _legendItem(
                  Icons.restaurant,
                  'Food',
                  '${food.toInt()}',
                  const Color(0xFF6FB36F), // leaf green (natura)
                  onCard,
                ),
                const SizedBox(height: 16),
                _legendItem(
                  Icons.local_fire_department,
                  'Exercise',
                  '${ex.toInt()}',
                  const Color(0xFFC9A227), // amber (calorie bruciate)
                  onCard,
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMacrosPage(
    NutrientGoal carbs,
    NutrientGoal fats,
    NutrientGoal proteins, {
    required Color onCard,
    required Color onCardMuted,
    required Color ringTrack,
  }) {
    return SizedBox.expand(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Macros',
            style: TextStyle(
              color: onCard,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 32),
          const Spacer(),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _macroCircle(
                carbs,
                'Carbs',
                onCard: onCard,
                onCardMuted: onCardMuted,
                ringTrack: ringTrack,
              ),
              _macroCircle(
                fats,
                'Fats',
                onCard: onCard,
                onCardMuted: onCardMuted,
                ringTrack: ringTrack,
              ),
              _macroCircle(
                proteins,
                'Proteins',
                onCard: onCard,
                onCardMuted: onCardMuted,
                ringTrack: ringTrack,
              ),
            ],
          ),
          const Spacer(),
        ],
      ),
    );
  }

  Widget _macroCircle(
    NutrientGoal goal,
    String label, {
    required Color onCard,
    required Color onCardMuted,
    required Color ringTrack,
  }) {
    final consumed = _valueForTodayInIsoWeek(goal.weeklyData);
    double target = goal.target;
    double left = target - consumed;
    final targetSafe = target <= 0 ? 1.0 : target;
    final macroProgress = (consumed / targetSafe).clamp(0.0, 1.0);

    return Column(
      children: [
        Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.none,
          children: [
            Padding(
              padding: const EdgeInsets.all(6),
              child: AnimProgressRing(
                progress: macroProgress,
                size: 96,
                strokeWidth: 8,
                accentColor: goal.color,
                trackColor: ringTrack,
              ),
            ),
            Text(
              '${consumed.toInt()}/${target.toInt()}',
              style: TextStyle(
                color: onCard,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            color: onCard,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        Text(
          '${left.toInt()}g left',
          style: TextStyle(color: onCardMuted, fontSize: 12),
        ),
      ],
    );
  }

  void _scheduleMacroFullCheck() {
    if (_macroCheckScheduled) return;
    _macroCheckScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _macroCheckScheduled = false;
      if (!mounted) return;
      _notifyIfMacroTargetReached();
    });
  }

  void _notifyIfMacroTargetReached() {
    final macros = <({String titlePart, String key, String labelIt})>[
      (titlePart: 'Carb', key: 'carbs', labelIt: 'carboidrati'),
      (titlePart: 'Grass', key: 'fats', labelIt: 'grassi'),
      (titlePart: 'Prot', key: 'proteins', labelIt: 'proteine'),
    ];

    for (final macro in macros) {
      if (_macroFullNotified.contains(macro.key)) continue;

      NutrientGoal goal;
      try {
        goal = _getGoalByTitle(macro.titlePart);
      } catch (_) {
        continue;
      }

      final target = goal.target;
      if (target <= 0) continue;

      final consumed = _valueForTodayInIsoWeek(goal.weeklyData);
      if (consumed < target) continue;

      _macroFullNotified.add(macro.key);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Obiettivo ${macro.labelIt} raggiunto per oggi!'),
          duration: const Duration(seconds: 4),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Widget _legendItem(
    IconData icon,
    String label,
    String val,
    Color iconColor,
    Color valColor,
  ) {
    return Row(
      children: [
        Icon(icon, size: 22, color: iconColor),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                color: iconColor.withValues(alpha: 0.8),
                fontSize: 12,
              ),
            ),
            Text(
              val,
              style: TextStyle(
                color: valColor,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDot(bool active, Color activeColor, Color inactiveColor) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      height: 8,
      width: 8,
      decoration: BoxDecoration(
        color: active ? activeColor : inactiveColor,
        shape: BoxShape.circle,
      ),
    );
  }
}
