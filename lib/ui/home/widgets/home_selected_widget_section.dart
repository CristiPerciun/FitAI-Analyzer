import 'package:fitai_analyzer/models/home_widget_type.dart';
import 'package:fitai_analyzer/models/meal_model.dart';
import 'package:fitai_analyzer/providers/nutrition_chart_provider.dart';
import 'package:fitai_analyzer/providers/providers.dart';
import 'package:fitai_analyzer/providers/user_profile_notifier.dart';
import 'package:fitai_analyzer/ui/alimentazione/widgets/caloric_deficit_bar_chart_card.dart';
import 'package:fitai_analyzer/ui/dashboard/widgets/activity_burn_bar_chart_card.dart';
import 'package:fitai_analyzer/ui/dashboard/widgets/activity_calendar_card.dart';
import 'package:fitai_analyzer/ui/widgets/NutritionChartCard.dart';
import 'package:fitai_analyzer/ui/widgets/weekly_macro_stacked_bar_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

double? _macroNum(Map<String, dynamic>? m, List<String> keys) {
  if (m == null) return null;
  for (final k in keys) {
    final v = m[k];
    if (v is num) return v.toDouble();
    final s = v?.toString();
    if (s == null) continue;
    final parsed = double.tryParse(s);
    if (parsed != null) return parsed;
  }
  return null;
}

/// Renderizza il widget scelto dall'utente per la Home.
class HomeSelectedWidgetSection extends ConsumerWidget {
  const HomeSelectedWidgetSection({
    super.key,
    required this.type,
    this.onRemove,
  });

  final HomeWidgetType type;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(type.icon, size: 18, color: theme.colorScheme.primary),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                type.title,
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            if (onRemove != null)
              IconButton(
                onPressed: onRemove,
                icon: const Icon(Icons.close, size: 20),
                color: theme.colorScheme.error,
                tooltip: 'Rimuovi dalla Home',
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
              ),
          ],
        ),
        const SizedBox(height: 8),
        switch (type) {
          HomeWidgetType.nutritionRings => const _HomeNutritionChartSection(),
          HomeWidgetType.caloricDeficit => const CaloricDeficitBarChartCard(),
          HomeWidgetType.weeklyMacros => const WeeklyMacroStackedBarChartCard(),
          HomeWidgetType.activityCalendar => const ActivityCalendarCard(),
          HomeWidgetType.activityBurn => const ActivityBurnBarChartCard(),
        },
      ],
    );
  }
}

class _HomeNutritionChartSection extends ConsumerWidget {
  const _HomeNutritionChartSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final nutritionGoal = ref.watch(nutritionGoalProvider);
    if (nutritionGoal == null) {
      return _HomeWidgetPlaceholder(
        icon: HomeWidgetType.nutritionRings.icon,
        message: 'Configura l\'obiettivo nutrizione in Alimentazione per vedere questo grafico.',
      );
    }

    final planAi = ref.watch(nutritionMealPlanAiStreamProvider).valueOrNull;
    final aiMacroGiornalieri = planAi?.macroGiornalieri;
    final obiettivoKcal = (_macroNum(aiMacroGiornalieri, ['kcal', 'calories']) ??
            nutritionGoal.calorieTarget)
        .round();
    final chartAsync = ref.watch(nutritionChartDataProvider);
    final profile = ref.watch(userProfileNotifierProvider).profile;

    return chartAsync.when(
      data: (chartData) {
        final goals = <NutrientGoal>[
          NutrientGoal(
            title: 'Calorie',
            unit: 'kcal',
            target: obiettivoKcal.toDouble(),
            color: Colors.blueAccent,
            weeklyData: chartData.caloriesData,
          ),
          NutrientGoal(
            title: 'Carboidrati',
            unit: 'g',
            target: _macroNum(aiMacroGiornalieri, ['carboidrati_g', 'carbs_g']) ?? 250.0,
            color: Colors.greenAccent,
            weeklyData: chartData.carbsData,
          ),
          NutrientGoal(
            title: 'Proteine',
            unit: 'g',
            target: _macroNum(aiMacroGiornalieri, ['proteine_g', 'protein_g']) ??
                (profile != null ? nutritionGoal.proteinGPerKg * profile.weightKg : 150.0),
            color: Colors.purpleAccent,
            weeklyData: chartData.proteinData,
          ),
          NutrientGoal(
            title: 'Grassi',
            unit: 'g',
            target: _macroNum(aiMacroGiornalieri, ['grassi_g', 'fat_g']) ?? 70.0,
            color: Colors.orangeAccent,
            weeklyData: chartData.fatData,
          ),
        ];

        return NutritionChartCard(allGoals: goals);
      },
      loading: () => const SizedBox(
        height: 200,
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => _HomeWidgetPlaceholder(
        icon: HomeWidgetType.nutritionRings.icon,
        message: 'Errore caricamento dati: $e',
      ),
    );
  }
}

class _HomeWidgetPlaceholder extends StatelessWidget {
  const _HomeWidgetPlaceholder({
    required this.icon,
    required this.message,
  });

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: theme.colorScheme.outline.withValues(alpha: 0.25),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: theme.colorScheme.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
