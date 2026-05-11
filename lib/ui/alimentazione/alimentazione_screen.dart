import 'dart:convert';

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
import 'package:fitai_analyzer/ui/onboarding/nutrition_goal_screen.dart';
import 'package:fitai_analyzer/utils/date_utils.dart' show dateFilterAll, formatDateForDisplay;
import 'package:fitai_analyzer/services/nutrition_service.dart';
import 'package:fitai_analyzer/theme/app_card_theme.dart';
import 'package:fitai_analyzer/ui/widgets/date_filter_chips.dart';
import 'package:fitai_analyzer/ui/widgets/error_dialog.dart';
import 'package:fitai_analyzer/utils/meal_constants.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fitai_analyzer/ui/widgets/NutritionChartCard.dart';
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
  ConsumerState<AlimentazioneScreen> createState() => _AlimentazioneScreenState();
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

  Map<String, dynamic> _mealModelToGeminiEditMap(MealModel meal) {
    final portion = meal.portionGrams;
    return {
      'dish_name': meal.displayTitle,
      'total_calories': meal.calories,
      'calories': meal.calories,
      'protein_g': meal.proteinG.round(),
      'carbs_g': meal.carbsG.round(),
      'fat_g': meal.fatG.round(),
      'sugar_g': 0,
      if (portion != null && portion > 0) 'estimated_portion_grams': portion,
      if (portion != null && portion > 0) 'portion_grams': portion,
      'advice': meal.rawAiAnalysis,
      'foods': meal.ingredients.map((name) => <String, dynamic>{'name': name}).toList(),
    };
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
      effectiveMealId = await ref.read(nutritionServiceProvider).resolveMealDocumentId(
            uid,
            dateStr,
            meal,
          );
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

    ref.read(nutritionMealEditProvider.notifier).beginFrom(_mealModelToGeminiEditMap(meal));

    showNutritionMealEditScreen(
      context,
      ref,
      _mealModelToGeminiEditMap(meal),
      uid: uid,
      mealLabel: meal.mealType.isNotEmpty ? meal.mealType.toLowerCase() : null,
      dateStr: dateStr,
      existingMealId: mealDocId,
      onDelete: () async {
        try {
          await ref.read(nutritionServiceProvider).deleteMeal(uid, dateStr, mealDocId);
          refreshNutritionAfterMealChange(ref);
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Pasto eliminato')),
            );
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
    final obiettivoKcal = (_macroNum(aiMacroGiornalieri, ['kcal', 'calories']) ??
            nutritionGoal?.calorieTarget ??
            0)
        .round();

    final uid = ref.watch(authNotifierProvider).user?.uid;
    final isGarminSyncing = ref.watch(
      garminSyncNotifierProvider.select((s) => s.isSyncing),
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Alimentazione'),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: false,
          tabAlignment: TabAlignment.fill,
          tabs: const [
            Tab(text: 'Obiettivi'),
            Tab(text: 'Diario'),
          ],
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
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
            if (nutritionGoal == null)
              _NutritionOnboardingCard(
                onConfigure: () {
                  Navigator.of(context).push<void>(
                    MaterialPageRoute<void>(
                      builder: (routeContext) => NutritionGoalScreen(
                        onSuccess: () {
                          Navigator.of(routeContext).pop();
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
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
                  final chartAsync = ref.watch(nutritionChartDataProvider);
                  final profile = ref.watch(userProfileNotifierProvider).profile;

                  return chartAsync.when(
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
                    loading: () => const SizedBox(height: 200, child: Center(child: CircularProgressIndicator())),
                    error: (e, __) => Text("Errore dati: $e"),
                  );
                },
              ),

            if (nutritionGoal != null) ...[
              const SizedBox(height: 16),
              Consumer(
                builder: (context, ref, _) {
                  final planAsync = ref.watch(nutritionMealPlanAiStreamProvider);
                  final plan = planAsync.valueOrNull;
                  if (plan == null || !plan.hasAnyObjective) {
                    return Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          size: 14,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Lancia l\'Analisi dalla Home per generare gli obiettivi pasti',
                            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                                ),
                          ),
                        ),
                      ],
                    );
                  }
                  if (plan.macroGiornalieri.isNotEmpty) {
                    return Text(
                      _macroSummaryLine(plan.macroGiornalieri),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),
            ],

            const SizedBox(height: 20),
            Text(
              'Date',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 8),
            DateFilterChips(
              selectedDate: selectedDate,
              onDateSelected: (d) => ref.read(selectedMealDateFilterProvider.notifier).state = d,
            ),

            const SizedBox(height: 20),
            if (displayDates.isEmpty)
              ..._buildMealCardsForDate(context, ref, todayStr)
            else
              ...displayDates.expand((dateKey) => [
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(
                        formatDateForDisplay(dateKey),
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              color: Theme.of(context).colorScheme.primary,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                    ),
                    ..._buildMealCardsForDate(context, ref, dateKey),
                    const SizedBox(height: 24),
                  ]),

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
    return parts.isEmpty ? '' : 'Macro giornalieri (da piano AI): ${parts.join(' · ')}';
  }

  List<Widget> _buildMealCardsForDate(BuildContext context, WidgetRef ref, String dateStr) {
    return [
      for (var i = 0; i < MealConstants.mealTypes.length; i++) ...[
        if (i > 0) const SizedBox(height: 16),
        _MealCardForDate(
          dateStr: dateStr,
          label: MealConstants.mealTypes[i],
          onTap: () => showAddMealSheet(
            context,
            ref,
            mealLabel: MealConstants.mealLabels[i],
            dateStr: dateStr,
          ),
          onMealEdit: (meal) => _showMealEditFromModel(context, ref, meal, dateStr),
          onRetryPending: (p) => retryPendingMealAnalysis(context, ref, p),
          onDismissPending: (id) => ref.read(pendingMealAnalysisProvider.notifier).remove(id),
        ),
        _MealAiObjectivesCard(pastoKey: MealConstants.mealLabels[i]),
      ],
    ];
  }
}

// ====================== WIDGETS AUSILIARI ======================
class _NutritionOnboardingCard extends StatelessWidget {
  const _NutritionOnboardingCard({required this.onConfigure});

  final VoidCallback onConfigure;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      elevation: 0,
      color: cs.primaryContainer,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.restaurant_menu, color: cs.onPrimaryContainer, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Obiettivo Mangiare',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: cs.onPrimaryContainer,
                        ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Imposta preferenze, obiettivo nutrizionale e target calorico. Poi vedrai qui obiettivo giornaliero, calorie assunte e kcal rimanenti.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: cs.onPrimaryContainer.withValues(alpha: 0.92),
                  ),
            ),
            const SizedBox(height: 16),
            FilledButton(onPressed: onConfigure, child: const Text('Configura obiettivo mangiare')),
          ],
        ),
      ),
    );
  }
}

class _MealCardForDate extends ConsumerWidget {
  const _MealCardForDate({
    required this.dateStr,
    required this.label,
    required this.onTap,
    required this.onMealEdit,
    required this.onRetryPending,
    required this.onDismissPending,
  });

  final String dateStr;
  final String label;
  final VoidCallback onTap;
  final void Function(MealModel meal) onMealEdit;
  final void Function(PendingMealAnalysis pending) onRetryPending;
  final void Function(String pendingId) onDismissPending;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mealsAsync = ref.watch(mealsForDateByTypeProvider(dateStr));
    final meals = mealsAsync.valueOrNull?[label] ?? [];
    final pendingMeals = ref
        .watch(pendingMealAnalysisProvider)
        .where((p) => p.dateStr == dateStr && p.mealTypeLabel == label)
        .toList();
    return _MealCard(
      label: label,
      meals: meals,
      pendingMeals: pendingMeals,
      onTap: onTap,
      onMealEdit: onMealEdit,
      onRetryPending: onRetryPending,
      onDismissPending: onDismissPending,
    );
  }
}

class _MealCard extends StatelessWidget {
  const _MealCard({
    required this.label,
    required this.meals,
    required this.pendingMeals,
    required this.onTap,
    required this.onMealEdit,
    required this.onRetryPending,
    required this.onDismissPending,
  });

  final String label;
  final List<MealModel> meals;
  final List<PendingMealAnalysis> pendingMeals;
  final VoidCallback onTap;
  final void Function(MealModel meal) onMealEdit;
  final void Function(PendingMealAnalysis pending) onRetryPending;
  final void Function(String pendingId) onDismissPending;

  @override
  Widget build(BuildContext context) {
    final cardTheme = Theme.of(context).extension<AppCardTheme>()!;

    return Container(
      decoration: cardTheme.gradientDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        label,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              color: cardTheme.contentColor,
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: cardTheme.contentColor.withValues(alpha: 0.3),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.add, color: cardTheme.contentColor, size: 24),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (pendingMeals.isNotEmpty || meals.isNotEmpty) ...[
            Divider(height: 1, color: cardTheme.contentColor.withValues(alpha: 0.4)),
            ...pendingMeals.map(
              (p) => _PendingMealTile(
                pending: p,
                cardTheme: cardTheme,
                onRetry: () => onRetryPending(p),
                onDismissError:
                    p.errorMessage != null ? () => onDismissPending(p.id) : null,
              ),
            ),
            ...meals.map((meal) => _MealTile(meal: meal, onTap: () => onMealEdit(meal))),
          ],
        ],
      ),
    );
  }
}

class _MealTile extends StatelessWidget {
  const _MealTile({required this.meal, required this.onTap});

  final MealModel meal;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cardTheme = Theme.of(context).extension<AppCardTheme>()!;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Row(
            children: [
              _MealThumbOrPlaceholder(meal: meal, cardTheme: cardTheme),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  meal.displayTitle,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: cardTheme.contentColor),
                ),
              ),
              Text(
                '${meal.calories} kcal',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: cardTheme.contentColor,
                    ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.chevron_right, color: cardTheme.contentColorMuted, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

class _MealThumbOrPlaceholder extends StatelessWidget {
  const _MealThumbOrPlaceholder({required this.meal, required this.cardTheme});

  final MealModel meal;
  final AppCardTheme cardTheme;

  static const double _size = 48;

  @override
  Widget build(BuildContext context) {
    final thumb = meal.mealThumbBase64;
    if (thumb != null && thumb.isNotEmpty) {
      try {
        final raw = base64Decode(thumb);
        return ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Image.memory(
            raw,
            width: _size,
            height: _size,
            fit: BoxFit.cover,
            gaplessPlayback: true,
          ),
        );
      } catch (_) {}
    }
    return Container(
      width: _size,
      height: _size,
      decoration: BoxDecoration(
        color: cardTheme.contentColor.withValues(alpha: 0.22),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(Icons.restaurant, color: cardTheme.contentColor, size: 24),
    );
  }
}

class _PendingMealTile extends StatelessWidget {
  const _PendingMealTile({
    required this.pending,
    required this.cardTheme,
    required this.onRetry,
    this.onDismissError,
  });

  final PendingMealAnalysis pending;
  final AppCardTheme cardTheme;
  final VoidCallback onRetry;
  final VoidCallback? onDismissError;

  static const double _thumbSize = 48;

  @override
  Widget build(BuildContext context) {
    final subtitle = pending.analyzing
        ? 'Analisi IA in corso…'
        : (pending.errorMessage ?? 'Errore');

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: _thumbSize,
            height: _thumbSize,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.memory(
                    pending.imageBytes,
                    fit: BoxFit.cover,
                    gaplessPlayback: true,
                  ),
                  if (pending.analyzing)
                    Center(
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: cardTheme.contentColor.withValues(alpha: 0.92),
                          shape: BoxShape.circle,
                        ),
                        child: SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Theme.of(context).colorScheme.surface,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Foto inviata all’IA',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: cardTheme.contentColor,
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: pending.errorMessage != null
                            ? Theme.of(context).colorScheme.error
                            : cardTheme.contentColorMuted,
                      ),
                ),
              ],
            ),
          ),
          if (!pending.analyzing && pending.errorMessage != null) ...[
            IconButton(
              onPressed: onRetry,
              icon: Icon(Icons.refresh, color: cardTheme.contentColor),
              tooltip: 'Riprova',
            ),
            if (onDismissError != null)
              IconButton(
                onPressed: onDismissError,
                icon: Icon(Icons.close, color: cardTheme.contentColorMuted),
                tooltip: 'Chiudi',
              ),
          ],
        ],
      ),
    );
  }
}

class _MealAiObjectivesCard extends ConsumerWidget {
  const _MealAiObjectivesCard({required this.pastoKey});

  final String pastoKey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plan = ref.watch(nutritionMealPlanAiStreamProvider).valueOrNull;
    if (plan == null || !plan.hasAnyObjective) return const SizedBox.shrink();

    // Per gli "spuntini" non c'è un blocco di obiettivi dedicato nel piano AI
    // (il piano copre colazione/pranzo/cena). Manteniamo la card vuota.
    final List<String> items = switch (pastoKey) {
      'colazione' => plan.obiettiviColazione,
      'pranzo' => plan.obiettiviPranzo,
      'cena' => plan.obiettiviCena,
      _ => const <String>[],
    };

    if (items.isEmpty) return const SizedBox.shrink();

    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Material(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.flag_outlined, size: 18, color: cs.primary),
                  const SizedBox(width: 8),
                  Text('Obiettivi per questo pasto', style: Theme.of(context).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600)),
                ],
              ),
              const SizedBox(height: 8),
              for (final t in items)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    children: [
                      Text('• ', style: TextStyle(color: cs.primary, fontWeight: FontWeight.bold)),
                      Expanded(child: Text(t, style: Theme.of(context).textTheme.bodySmall)),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
