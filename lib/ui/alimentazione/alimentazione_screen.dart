import 'package:fitai_analyzer/models/meal_model.dart';
import 'package:fitai_analyzer/providers/auth_notifier.dart';
import 'package:fitai_analyzer/providers/garmin_sync_notifier.dart';
import 'package:fitai_analyzer/providers/nutrition_chart_provider.dart';
import 'package:fitai_analyzer/providers/nutrition_meal_edit_provider.dart';
import 'package:fitai_analyzer/providers/pending_meal_analysis_provider.dart';
import 'package:fitai_analyzer/providers/providers.dart';
import 'package:fitai_analyzer/providers/user_profile_notifier.dart';
import 'package:fitai_analyzer/ui/alimentazione/alimentazione_objectives_tab.dart';
import 'package:fitai_analyzer/ui/alimentazione/meal_capture_flow.dart';
import 'package:fitai_analyzer/ui/alimentazione/widgets/meal_ai_objectives_card.dart';
import 'package:fitai_analyzer/ui/alimentazione/widgets/meal_cards.dart';
import 'package:fitai_analyzer/ui/alimentazione/widgets/nutrition_onboarding_card.dart';
import 'package:fitai_analyzer/ui/onboarding/nutrition_goal_screen.dart';
import 'package:fitai_analyzer/utils/date_utils.dart'
    show dateFilterAll, formatDateForDisplay;
import 'package:fitai_analyzer/services/nutrition_service.dart';
import 'package:fitai_analyzer/ui/widgets/date_filter_chips.dart';
import 'package:fitai_analyzer/ui/widgets/error_dialog.dart';
import 'package:fitai_analyzer/utils/meal_constants.dart';
import 'package:fitai_analyzer/utils/nutrition_macro_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fitai_analyzer/ui/widgets/NutritionChartCard.dart';
import 'package:fitai_analyzer/ui/alimentazione/widgets/caloric_deficit_bar_chart_card.dart';
import 'package:fitai_analyzer/ui/widgets/weekly_macro_stacked_bar_chart.dart';

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

class AlimentazioneScreen extends ConsumerStatefulWidget {
  const AlimentazioneScreen({super.key});

  @override
  ConsumerState<AlimentazioneScreen> createState() =>
      _AlimentazioneScreenState();
}

class _AlimentazioneScreenState extends ConsumerState<AlimentazioneScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _showMealEditFromModel(
    BuildContext context,
    WidgetRef ref,
    MealModel meal,
    String dateStr,
  ) async {
    final uid = await ensureNutritionUid(context, ref);
    if (uid == null || !context.mounted) return;

    var effectiveMealId = meal.firestoreDocumentId?.trim();
    if (effectiveMealId == null || effectiveMealId.isEmpty) {
      effectiveMealId = await ref
          .read(nutritionServiceProvider)
          .resolveMealDocumentId(uid, dateStr, meal);
    }

    if (effectiveMealId == null || effectiveMealId.isEmpty) {
      if (!context.mounted) return;
      showErrorDialog(
        context,
        'Impossibile individuare questo pasto nel diario. Riprova tra un attimo o aggiungi un nuovo pasto.',
      );
      return;
    }

    final mealDocId = effectiveMealId;

    if (!context.mounted) return;

    ref
        .read(nutritionMealEditProvider.notifier)
        .beginFrom(NutritionService.mealModelToGeminiEditMap(meal));

    showNutritionMealEditScreen(
      context,
      ref,
      NutritionService.mealModelToGeminiEditMap(meal),
      uid: uid,
      mealLabel: meal.mealType.isNotEmpty ? meal.mealType.toLowerCase() : null,
      dateStr: dateStr,
      existingMealId: mealDocId,
      onDelete: () async {
        try {
          await ref
              .read(nutritionServiceProvider)
              .deleteMeal(uid, dateStr, mealDocId);
          refreshNutritionAfterMealChange(ref);
          if (context.mounted) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(const SnackBar(content: Text('Pasto eliminato')));
          }
        } catch (e) {
          if (context.mounted) showErrorDialog(context, e.toString());
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final ref = this.ref;
    final datesAsync = ref.watch(mealDatesProvider);
    final dates = datesAsync.valueOrNull ?? [];
    final selectedDate = ref.watch(selectedMealDateFilterProvider);
    final todayStr = DateTime.now().toIso8601String().split('T')[0];
    final displayDates = selectedDate == null
        ? [todayStr]
        : selectedDate == dateFilterAll
        ? (dates.isNotEmpty ? dates : [])
        : [selectedDate];

    final nutritionGoal = ref.watch(nutritionGoalProvider);
    final planAi = ref.watch(nutritionMealPlanAiStreamProvider).valueOrNull;
    final aiMacroGiornalieri = planAi?.macroGiornalieri;

    // Obiettivo "vero" usato sia nei grafici sia nella card: quello calcolato dall'IA.
    // Fallback: se il piano AI non esiste ancora, usiamo l'obiettivo configurato dall'utente.
    final obiettivoKcal =
        (_macroNum(aiMacroGiornalieri, ['kcal', 'calories']) ??
                nutritionGoal?.calorieTarget ??
                0)
            .round();

    final uid = ref.watch(authNotifierProvider).user?.uid;
    final isGarminSyncing = ref.watch(
      garminSyncNotifierProvider.select((s) => s.isSyncing),
    );

    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Alimentazione'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            child: Container(
              height: 44,
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(999),
              ),
              child: TabBar(
                controller: _tabController,
                isScrollable: false,
                tabAlignment: TabAlignment.fill,
                dividerColor: Colors.transparent,
                indicatorSize: TabBarIndicatorSize.tab,
                splashBorderRadius: BorderRadius.circular(999),
                indicator: BoxDecoration(
                  color: theme.colorScheme.primary,
                  borderRadius: BorderRadius.circular(999),
                ),
                labelColor: theme.colorScheme.onPrimary,
                unselectedLabelColor: theme.colorScheme.onSurfaceVariant,
                labelStyle: const TextStyle(fontWeight: FontWeight.w600),
                tabs: const [
                  Tab(text: 'Obiettivi'),
                  Tab(text: 'Diario'),
                ],
              ),
            ),
          ),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            if (isGarminSyncing) const LinearProgressIndicator(minHeight: 2),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  const AlimentazioneObjectivesTab(),
                  RefreshIndicator(
                    onRefresh: () async {
                      await refreshGarminSync(
                        ref,
                        uid,
                        trigger: 'alimentazione_pull_to_refresh',
                      );
                      ref.invalidate(nutritionChartDataProvider);
                      ref.invalidate(nutritionDiaryWeekChartDataProvider);
                    },
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (nutritionGoal == null)
                            NutritionOnboardingCard(
                              onConfigure: () {
                                Navigator.of(context).push<void>(
                                  MaterialPageRoute<void>(
                                    builder: (routeContext) => NutritionGoalScreen(
                                      onSuccess: () {
                                        Navigator.of(routeContext).pop();
                                        if (context.mounted) {
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            const SnackBar(
                                              content: Text(
                                                'Obiettivo mangiare e piano pasti salvati',
                                              ),
                                            ),
                                          );
                                        }
                                      },
                                    ),
                                  ),
                                );
                              },
                            )
                          else
                            Consumer(
                              builder: (context, ref, _) {
                                // Recuperiamo i dati settimanali aggiornati per i grafici
                                final chartAsync = ref.watch(
                                  nutritionChartDataProvider,
                                );
                                final profile = ref
                                    .watch(userProfileNotifierProvider)
                                    .profile;

                                return chartAsync.when(
                                  skipLoadingOnReload: true,
                                  data: (chartData) {
                                    // Costruiamo la lista di obiettivi reali per la card
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
                                        target:
                                            _macroNum(aiMacroGiornalieri, [
                                              'carboidrati_g',
                                              'carbs_g',
                                            ]) ??
                                            250.0,
                                        color: NutritionMacroColors.carbs,
                                        weeklyData: chartData.carbsData,
                                      ),
                                      NutrientGoal(
                                        title: 'Proteine',
                                        unit: 'g',
                                        target:
                                            _macroNum(aiMacroGiornalieri, [
                                              'proteine_g',
                                              'protein_g',
                                            ]) ??
                                            (profile != null
                                                ? nutritionGoal.proteinGPerKg *
                                                      profile.weightKg
                                                : 150.0),
                                        color: NutritionMacroColors.protein,
                                        weeklyData: chartData.proteinData,
                                      ),
                                      NutrientGoal(
                                        title: 'Grassi',
                                        unit: 'g',
                                        target:
                                            _macroNum(aiMacroGiornalieri, [
                                              'grassi_g',
                                              'fat_g',
                                            ]) ??
                                            70.0,
                                        color: NutritionMacroColors.fat,
                                        weeklyData: chartData.fatData,
                                      ),
                                    ];

                                    return NutritionChartCard(allGoals: goals);
                                  },
                                  loading: () => const SizedBox(
                                    height: 200,
                                    child: Center(
                                      child: CircularProgressIndicator(),
                                    ),
                                  ),
                                  error: (e, _) => Text("Errore dati: $e"),
                                );
                              },
                            ),

                          if (nutritionGoal != null) ...[
                            const SizedBox(height: 16),
                            Consumer(
                              builder: (context, ref, _) {
                                final planAsync = ref.watch(
                                  nutritionMealPlanAiStreamProvider,
                                );
                                final plan = planAsync.valueOrNull;
                                if (plan == null || !plan.hasAnyObjective) {
                                  return Row(
                                    children: [
                                      Icon(
                                        Icons.info_outline,
                                        size: 14,
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.onSurfaceVariant,
                                      ),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          'Lancia l\'Analisi dalla Home per generare gli obiettivi pasti',
                                          style: Theme.of(context)
                                              .textTheme
                                              .labelSmall
                                              ?.copyWith(
                                                color: Theme.of(
                                                  context,
                                                ).colorScheme.onSurfaceVariant,
                                              ),
                                        ),
                                      ),
                                    ],
                                  );
                                }
                                if (plan.macroGiornalieri.isNotEmpty) {
                                  return Text(
                                    _macroSummaryLine(plan.macroGiornalieri),
                                    style: Theme.of(context).textTheme.bodySmall
                                        ?.copyWith(
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.onSurfaceVariant,
                                        ),
                                  );
                                }
                                return const SizedBox.shrink();
                              },
                            ),
                          ],

                          const SizedBox(height: 16),
                          const CaloricDeficitBarChartCard(),

                          const SizedBox(height: 20),
                          Text(
                            'Date',
                            style: Theme.of(context).textTheme.titleSmall
                                ?.copyWith(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                          const SizedBox(height: 8),
                          DateFilterChips(
                            selectedDate: selectedDate,
                            onDateSelected: (d) =>
                                ref
                                        .read(
                                          selectedMealDateFilterProvider
                                              .notifier,
                                        )
                                        .state =
                                    d,
                          ),

                          const SizedBox(height: 20),
                          if (displayDates.isEmpty)
                            ..._buildMealCardsForDate(context, ref, todayStr)
                          else
                            ...displayDates.expand(
                              (dateKey) => [
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: Text(
                                    formatDateForDisplay(dateKey),
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleSmall
                                        ?.copyWith(
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.primary,
                                          fontWeight: FontWeight.w600,
                                        ),
                                  ),
                                ),
                                ..._buildMealCardsForDate(
                                  context,
                                  ref,
                                  dateKey,
                                ),
                                const SizedBox(height: 24),
                              ],
                            ),

                          const SizedBox(height: 24),
                          const WeeklyMacroStackedBarChartCard(),
                          const SizedBox(height: 40),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _macroSummaryLine(Map<String, dynamic> m) {
    num? n(String a, String b) {
      final v = m[a] ?? m[b];
      if (v is num) return v;
      return num.tryParse(v?.toString() ?? '');
    }

    final p = n('proteine_g', 'protein_g');
    final c = n('carboidrati_g', 'carbs_g');
    final f = n('grassi_g', 'fat_g');
    final k = n('kcal', 'calories');
    final parts = <String>[];
    if (p != null) parts.add('P: ${p.round()} g');
    if (c != null) parts.add('C: ${c.round()} g');
    if (f != null) parts.add('G: ${f.round()} g');
    if (k != null) parts.add('${k.round()} kcal');
    return parts.isEmpty
        ? ''
        : 'Macro giornalieri (da piano AI): ${parts.join(' · ')}';
  }

  List<Widget> _buildMealCardsForDate(
    BuildContext context,
    WidgetRef ref,
    String dateStr,
  ) {
    return [
      for (var i = 0; i < MealConstants.mealTypes.length; i++) ...[
        if (i > 0) const SizedBox(height: 16),
        MealCardForDate(
          dateStr: dateStr,
          label: MealConstants.mealTypes[i],
          onTap: () => showAddMealSheet(
            context,
            ref,
            mealLabel: MealConstants.mealLabels[i],
            dateStr: dateStr,
          ),
          onMealEdit: (meal) =>
              _showMealEditFromModel(context, ref, meal, dateStr),
          onRetryPending: (p) => retryPendingMealAnalysis(context, ref, p),
          onDismissPending: (id) =>
              ref.read(pendingMealAnalysisProvider.notifier).remove(id),
        ),
        MealAiObjectivesCard(pastoKey: MealConstants.mealLabels[i]),
      ],
    ];
  }
}
