import 'dart:ui';

import 'package:fitai_analyzer/models/meal_model.dart';
import 'package:fitai_analyzer/providers/today_longevity_metrics_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
    // ESTRAZIONE DATI REALI DAL PROGETTO
    final calGoal = _getGoalByTitle("Calorie");
    final carbGoal = _getGoalByTitle("Carb");
    final protGoal = _getGoalByTitle("Prot");
    final fatGoal = _getGoalByTitle("Grass");

    // Calcolo valori reali
    double targetCal = calGoal.target;
    double foodCal = calGoal.weeklyData.isNotEmpty
        ? calGoal.weeklyData.last.value
        : 0;

    final double exercise = metrics.caloriesBurned;
    final double remainingCal = targetCal - foodCal + exercise;
    return Container(
      width: MediaQuery.of(context).size.width * 0.90,
      margin: const EdgeInsets.symmetric(vertical: 10),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
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
                  ),
                  _buildMacrosPage(carbGoal, fatGoal, protGoal),
                  _buildInsightsPage(),
                ],
              ),
            ),
          ),

          const SizedBox(height: 15),

          // INDICATORE PUNTINI
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              3,
              (index) => _buildDot(index == _currentPage),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTodayPage(double rem, double target, double food, double ex, Color accentColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Today", style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
        Text("Remaining = Goal - Food + Exercise", style: TextStyle(color: Colors.grey[600], fontSize: 11)),
        const SizedBox(height: 25),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 115, height: 115,
                  child: CircularProgressIndicator(
                    value: (food / target).clamp(0, 1),
                    strokeWidth: 9,
                    backgroundColor: Colors.white.withOpacity(0.05),
                    valueColor: AlwaysStoppedAnimation<Color>(accentColor),
                    strokeCap: StrokeCap.round,
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text("${rem.toInt()}", style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold)),
                    Text("Remaining", style: TextStyle(color: Colors.grey[500], fontSize: 10)),
                  ],
                )
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _legendItem(Icons.flag, "Base Goal", "${target.toInt()}", Colors.grey),
                const SizedBox(height: 12),
                _legendItem(Icons.restaurant, "Food", "${food.toInt()}", Colors.blueAccent),
                const SizedBox(height: 12),
                _legendItem(Icons.local_fire_department, "Exercise", "${ex.toInt()}", Colors.orangeAccent),
              ],
            )
          ],
        ),
      ],
    );
  }

  Widget _buildMacrosPage(NutrientGoal carbs, NutrientGoal fats, NutrientGoal proteins) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Macros", style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
        const SizedBox(height: 30),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _macroCircle(carbs, "Carbs"),
            _macroCircle(fats, "Fats"),
            _macroCircle(proteins, "Proteins"),
          ],
        ),
      ],
    );
  }

  Widget _macroCircle(NutrientGoal goal, String label) {
    double consumed = goal.weeklyData.isNotEmpty ? goal.weeklyData.last.value : 0;
    double target = goal.target;
    double left = target - consumed;

    return Column(
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            SizedBox(
              width: 65, height: 65,
              child: CircularProgressIndicator(
                value: (consumed / target).clamp(0, 1),
                strokeWidth: 6,
                backgroundColor: Colors.white.withOpacity(0.05),
                valueColor: AlwaysStoppedAnimation<Color>(goal.color),
                strokeCap: StrokeCap.round,
              ),
            ),
            Text("${consumed.toInt()}/${target.toInt()}", style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 8),
        Text(label, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500)),
        Text("${left.toInt()}g left", style: TextStyle(color: Colors.grey[600], fontSize: 10)),
      ],
    );
  }

  Widget _legendItem(IconData icon, String label, String val, Color col) {
    return Row(
      children: [
        Icon(icon, size: 16, color: col),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(color: Colors.grey[500], fontSize: 10)),
            Text(val, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
          ],
        )
      ],
    );
  }
Widget _buildInsightsPage() {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text("AI Insights", 
        style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
      const SizedBox(height: 20),
      Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: Colors.blueAccent.withOpacity(0.1),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: Colors.blueAccent.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            const Icon(Icons.auto_awesome, color: Colors.blueAccent, size: 30),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Analisi Odierna", 
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                  const SizedBox(height: 5),
                  Text(
                    "Stai andando forte! Hai assunto abbastanza proteine. Ricorda di bere più acqua per ottimizzare il metabolismo.",
                    style: TextStyle(color: Colors.grey[400], fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 15),
      // Un piccolo indicatore extra (es: Acqua o Fibre)
      _legendItem(Icons.water_drop, "Hydration", "1.5 / 2.5 L", Colors.cyan),
    ],
  );
}
  Widget _buildDot(bool active) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      height: 8, width: 8,
      decoration: BoxDecoration(color: active ? Colors.blue : Colors.white24, shape: BoxShape.circle),
    );
  }
}