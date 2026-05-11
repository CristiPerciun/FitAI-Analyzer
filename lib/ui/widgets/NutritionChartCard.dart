import 'dart:ui';

import 'package:fitai_analyzer/models/meal_model.dart';
import 'package:fitai_analyzer/providers/today_longevity_metrics_provider.dart';
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
  int _currentPage = 0;

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

    // Colori card adattativi al tema corrente.
    final cardBg = isDark
        ? const Color(0xFF1A1A1A)
        : theme.colorScheme.surfaceContainerHighest;
    final cardBorder = isDark
        ? Colors.white.withValues(alpha: 0.05)
        : theme.colorScheme.outline.withValues(alpha: 0.15);
    final onCard = theme.colorScheme.onSurface;
    final onCardMuted = theme.colorScheme.onSurfaceVariant;
    final ringTrack = theme.colorScheme.onSurface.withValues(alpha: isDark ? 0.05 : 0.10);
    final dotActive = theme.colorScheme.primary;
    final dotInactive = theme.colorScheme.onSurface.withValues(alpha: isDark ? 0.24 : 0.20);

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
    return Container(
      width: MediaQuery.of(context).size.width * 0.90,
      margin: const EdgeInsets.symmetric(vertical: 10),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: cardBorder),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: 240,
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
                  controller: _pageController,
                  physics: const BouncingScrollPhysics(),
                  onPageChanged: (int page) {
                    setState(() {
                      _currentPage = page;
                    });
                  },
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
                    _buildInsightsPage(
                      theme: theme,
                      onCard: onCard,
                      onCardMuted: onCardMuted,
                    ),
                  ],
                ),
              ),
            ),
          ),

          const SizedBox(height: 15),

          // INDICATORE PUNTINI
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              3,
              (index) => _buildDot(index == _currentPage, dotActive, dotInactive),
            ),
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
        Text('Today', style: TextStyle(color: onCard, fontSize: 22, fontWeight: FontWeight.bold)),
        Text(
          'Remaining = Goal - Food + Exercise',
          style: TextStyle(color: onCardMuted, fontSize: 11),
        ),
        const SizedBox(height: 25),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            Stack(
              alignment: Alignment.center,
              children: [
                _AnimNutritionProgressRing(
                  progress: foodProgress,
                  size: 115,
                  strokeWidth: 9,
                  accentColor: accentColor,
                  trackColor: ringTrack,
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${rem.toInt()}',
                      style: TextStyle(color: onCard, fontSize: 26, fontWeight: FontWeight.bold),
                    ),
                    Text('Remaining', style: TextStyle(color: onCardMuted, fontSize: 10)),
                  ],
                )
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _legendItem(Icons.flag, 'Base Goal', '${target.toInt()}', onCardMuted, onCard),
                const SizedBox(height: 12),
                _legendItem(Icons.restaurant, 'Food', '${food.toInt()}', Colors.blueAccent, onCard),
                const SizedBox(height: 12),
                _legendItem(Icons.local_fire_department, 'Exercise', '${ex.toInt()}', Colors.orangeAccent, onCard),
              ],
            )
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Macros', style: TextStyle(color: onCard, fontSize: 22, fontWeight: FontWeight.bold)),
        const SizedBox(height: 30),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _macroCircle(carbs, 'Carbs', onCard: onCard, onCardMuted: onCardMuted, ringTrack: ringTrack),
            _macroCircle(fats, 'Fats', onCard: onCard, onCardMuted: onCardMuted, ringTrack: ringTrack),
            _macroCircle(proteins, 'Proteins', onCard: onCard, onCardMuted: onCardMuted, ringTrack: ringTrack),
          ],
        ),
      ],
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
          children: [
            _AnimNutritionProgressRing(
              progress: macroProgress,
              size: 65,
              strokeWidth: 6,
              accentColor: goal.color,
              trackColor: ringTrack,
            ),
            Text(
              '${consumed.toInt()}/${target.toInt()}',
              style: TextStyle(color: onCard, fontSize: 9, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(label, style: TextStyle(color: onCard, fontSize: 12, fontWeight: FontWeight.w500)),
        Text('${left.toInt()}g left', style: TextStyle(color: onCardMuted, fontSize: 10)),
      ],
    );
  }

  Widget _legendItem(IconData icon, String label, String val, Color iconColor, Color valColor) {
    return Row(
      children: [
        Icon(icon, size: 16, color: iconColor),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(color: iconColor.withValues(alpha: 0.8), fontSize: 10)),
            Text(val, style: TextStyle(color: valColor, fontSize: 14, fontWeight: FontWeight.bold)),
          ],
        )
      ],
    );
  }

  Widget _buildInsightsPage({
    required ThemeData theme,
    required Color onCard,
    required Color onCardMuted,
  }) {
    final cs = theme.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('AI Insights', style: TextStyle(color: onCard, fontSize: 22, fontWeight: FontWeight.bold)),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            color: cs.primaryContainer.withValues(alpha: 0.35),
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: cs.primary.withValues(alpha: 0.25)),
          ),
          child: Row(
            children: [
              Icon(Icons.auto_awesome, color: cs.primary, size: 30),
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Analisi Odierna',
                      style: TextStyle(color: onCard, fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      'Stai andando forte! Hai assunto abbastanza proteine. Ricorda di bere più acqua per ottimizzare il metabolismo.',
                      style: TextStyle(color: onCardMuted, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 15),
        _legendItem(Icons.water_drop, 'Hydration', '1.5 / 2.5 L', Colors.cyan, onCard),
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

/// Cerchio calorie/macro con transizione graduale (~2s). Usa [TweenAnimationBuilder] per evitare
/// più [AnimationController] nel [PageView] (pagine non visibili / ticker: i macro non si aggiornavano).
class _AnimNutritionProgressRing extends StatefulWidget {
  const _AnimNutritionProgressRing({
    required this.progress,
    required this.size,
    required this.strokeWidth,
    required this.accentColor,
    required this.trackColor,
  });

  final double progress;
  final double size;
  final double strokeWidth;
  final Color accentColor;
  final Color trackColor;

  @override
  State<_AnimNutritionProgressRing> createState() => _AnimNutritionProgressRingState();
}

class _AnimNutritionProgressRingState extends State<_AnimNutritionProgressRing> {
  static const Duration _duration = Duration(seconds: 2);

  late double _tweenBegin;
  late double _tweenEnd;

  @override
  void initState() {
    super.initState();
    final p = widget.progress.clamp(0.0, 1.0);
    _tweenBegin = p;
    _tweenEnd = p;
  }

  @override
  void didUpdateWidget(covariant _AnimNutritionProgressRing oldWidget) {
    super.didUpdateWidget(oldWidget);
    final next = widget.progress.clamp(0.0, 1.0);
    if ((next - _tweenEnd).abs() < 0.0001) return;
    _tweenBegin = _tweenEnd;
    _tweenEnd = next;
  }

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      duration: _duration,
      curve: Curves.easeOutCubic,
      tween: Tween<double>(begin: _tweenBegin, end: _tweenEnd),
      builder: (context, value, _) {
        return SizedBox(
          width: widget.size,
          height: widget.size,
          child: CircularProgressIndicator(
            value: value.clamp(0.0, 1.0),
            strokeWidth: widget.strokeWidth,
            backgroundColor: widget.trackColor,
            valueColor: AlwaysStoppedAnimation<Color>(widget.accentColor),
            strokeCap: StrokeCap.round,
          ),
        );
      },
    );
  }
}
