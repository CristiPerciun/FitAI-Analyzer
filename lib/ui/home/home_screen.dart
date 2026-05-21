import 'package:fitai_analyzer/models/longevity_home_package.dart';
import 'package:fitai_analyzer/models/home_longevity_plan_day.dart';
import 'package:fitai_analyzer/providers/auth_notifier.dart';
import 'package:fitai_analyzer/providers/garmin_sync_notifier.dart'
    show GarminSyncState, garminSyncNotifierProvider;
import 'package:fitai_analyzer/providers/home_widget_preference_provider.dart';
import 'package:fitai_analyzer/providers/providers.dart';
import 'package:fitai_analyzer/services/nutrition_service.dart';
import 'package:fitai_analyzer/utils/boot_log.dart';
import 'package:fitai_analyzer/utils/meal_constants.dart';
import 'package:fitai_analyzer/ui/alimentazione/meal_capture_flow.dart';
import 'package:fitai_analyzer/ui/home/widgets/garmin_daily_stats.dart';
import 'package:fitai_analyzer/ui/home/widgets/longevity_header.dart';
import 'package:fitai_analyzer/ui/home/widgets/longevity_path_section.dart';
import 'package:fitai_analyzer/ui/home/widgets/home_action_card.dart';
import 'package:fitai_analyzer/ui/home/widgets/home_selected_widget_section.dart';
import 'package:fitai_analyzer/ui/home/widgets/home_widget_add_card.dart';
import 'package:fitai_analyzer/ui/home/widgets/home_widget_picker_sheet.dart';
import 'package:fitai_analyzer/ui/home/widgets/pillar_grid.dart';
import 'package:fitai_analyzer/ui/home/widgets/weekly_sprint_card.dart';
import 'package:fitai_analyzer/ui/widgets/error_dialog.dart';
import 'package:fitai_analyzer/ui/widgets/ai_backend_key_gate.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Home con struttura a scorrimento verticale: 4 pilastri della longevità.
/// 1. Header Dinamico (Carico di Longevità odierno)
/// 2. Griglia AI 2x2 (Daily Goals: Cuore, Forza, Alimentazione, Recupero)
/// 3. Weekly Sprint (obiettivo 7 giorni)
/// 4. Longevity Path (trend mensile Livello 3)
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  String? _lastHomeUiPhase;
  String? _lastPkgListenSig;

  void _traceHomeUi(String label) {
    if (_lastHomeUiPhase == label) return;
    _lastHomeUiPhase = label;
    bootLog('HomeScreen: $label');
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AsyncValue<LongevityHomePackage>>(
      longevityHomePackageProvider,
      (prev, next) {
        final n =
            'loading=${next.isLoading} data=${next.hasValue} err=${next.hasError}';
        if (_lastPkgListenSig == n) return;
        _lastPkgListenSig = n;
        final p = prev == null
            ? 'null'
            : 'loading=${prev.isLoading} data=${prev.hasValue} err=${prev.hasError}';
        bootLog('HomeScreen: listener pacchetto $p → $n');
      },
    );

    ref.listen<GarminSyncState>(
      garminSyncNotifierProvider,
      (prev, next) {
        if (!context.mounted) return;
        final prevErr = prev?.error;
        final nextErr = next.error;
        if (nextErr != null && nextErr != prevErr) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Sync Garmin non riuscita: $nextErr'),
              backgroundColor: Theme.of(context).colorScheme.error,
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 4),
            ),
          );
        } else if (prev != null &&
            prev.isSyncing &&
            !next.isSyncing &&
            next.error == null &&
            (next.trigger == 'home_pull_to_refresh')) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Dati Garmin aggiornati'),
              behavior: SnackBarBehavior.floating,
              duration: Duration(seconds: 2),
            ),
          );
        }
      },
    );

    final uid = ref.watch(authNotifierProvider).user?.uid;
    final packageAsync = ref.watch(longevityHomePackageProvider);
    final planDay = ref.watch(homeLongevityPlanForUiProvider);
    final dailyGoals = ref.watch(homeDailyGoalsMapProvider);
    final pillarCompletion = ref.watch(homePillarCompletionMapProvider);
    final weeklySprint = planDay?.weeklySprint;
    final strategicAdvice = planDay?.strategicAdvice;
    final isLoadingPlan = ref.watch(_longevityPlanLoadingProvider);
    final isGarminSyncing =
        ref.watch(garminSyncNotifierProvider.select((s) => s.isSyncing));
    final homeWidgetAsync = ref.watch(homeWidgetPreferenceProvider);
    final homeWidgetType = homeWidgetAsync.valueOrNull;
    final homeWidgetReady = !homeWidgetAsync.isLoading;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Home'),
        actions: [
          TextButton(
            onPressed: uid == null ? null : () => _onGeneratePlan(context),
            child: const Text('Analisi'),
          ),
        ],
      ),
      body: Column(
        children: [
          if (isGarminSyncing) const LinearProgressIndicator(minHeight: 2),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => _onRefreshGarmin(uid),
              child: packageAsync.when(
                data: (package) {
                  _traceHomeUi(
                    'UI elenco — dati pacchetto longevità (no spinner centrale)',
                  );
                  return CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const LongevityHeader(),
                            const SizedBox(height: 24),
                            Text(
                              'Obiettivi giornalieri',
                              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                                    fontWeight: FontWeight.w600,
                                  ),
                            ),
                            if (uid != null &&
                                MealConstants.isMainMealWindow(DateTime.now()) &&
                                !_hasMealForCurrentSlot(ref, localCalendarDateKey())) ...[
                              const SizedBox(height: 10),
                              HomeActionCard(
                                onTap: () => _onAddMealFromHome(context),
                                label: 'Aggiungi pasto',
                                semanticLabel: 'Aggiungi pasto',
                              ),
                            ],
                            const SizedBox(height: 12),
                            PillarGrid(
                              isLoading: isLoadingPlan,
                              pillarContents: dailyGoals.isEmpty ? null : dailyGoals,
                              pillarCompletion: pillarCompletion,
                              onGenerateTap: () => _onGeneratePlan(context),
                              onPillarCompletionAnswer: (pillar, completed) =>
                                  _onPillarCompletion(context, ref, pillar, completed),
                            ),
                            if (homeWidgetReady && homeWidgetType != null) ...[
                              const SizedBox(height: 12),
                              HomeSelectedWidgetSection(
                                type: homeWidgetType,
                                onRemove: () => ref
                                    .read(homeWidgetPreferenceProvider.notifier)
                                    .clearWidget(),
                              ),
                            ],
                            const SizedBox(height: 12),
                            HomeWidgetAddCard(
                              hasSelection: homeWidgetReady && homeWidgetType != null,
                              onTap: () => showHomeWidgetPickerSheet(context, ref),
                              onRemove: homeWidgetReady && homeWidgetType != null
                                  ? () => ref
                                      .read(homeWidgetPreferenceProvider.notifier)
                                      .clearWidget()
                                  : null,
                            ),
                            const SizedBox(height: 16),
                            const GarminDailyStats(),
                            const SizedBox(height: 24),
                            Text(
                              'Weekly & Long-Term',
                              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                                    fontWeight: FontWeight.w600,
                                  ),
                            ),
                            const SizedBox(height: 12),
                            WeeklySprintCard(
                              content: weeklySprint,
                              isLoading: isLoadingPlan,
                              onGenerateTap: () => _onGeneratePlan(context),
                            ),
                            const SizedBox(height: 24),
                            LongevityPathSection(
                              baseline: package.baseline,
                              strategicAdvice: strategicAdvice,
                              isLoading: isLoadingPlan,
                              onGenerateTap: () => _onGeneratePlan(context),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
                },
                loading: () {
                  _traceHomeUi(
                    'UI spinner centrale — stesso provider ancora in loading '
                    '(può comparire dopo il Launch se il FutureProvider si è reinizializzato)',
                  );
                  return ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: const [
                    SizedBox(height: 220),
                    Center(child: CircularProgressIndicator()),
                  ],
                );
                },
                error: (e, _) {
                  _traceHomeUi('UI errore pacchetto: $e');
                  return ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        children: [
                          const SizedBox(height: 120),
                          Icon(
                            Icons.error_outline,
                            size: 48,
                            color: Theme.of(context).colorScheme.error,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            e.toString(),
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ],
                      ),
                    ),
                  ],
                );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  bool _hasMealForCurrentSlot(WidgetRef ref, String dateStr) {
    final async = ref.watch(mealsForDateByTypeProvider(dateStr));
    final label = MealConstants.mealLabelForTime(DateTime.now());
    final type = MealConstants.toMealType(label);
    return async.maybeWhen(
      data: (map) => (map[type] ?? []).isNotEmpty,
      orElse: () => false,
    );
  }

  Future<void> _onGeneratePlan(BuildContext context) async {
    final ref = this.ref;
    final uid = ref.read(authNotifierProvider).user?.uid;
    if (uid == null) {
      if (context.mounted) showErrorDialog(context, 'Utente non autenticato.');
      return;
    }

    if (!await ensureActiveAiBackendHasKey(context, ref)) {
      return;
    }
    if (!context.mounted) return;

    final today = localCalendarDateKey();
    final hasRecorded =
        await ref.read(nutritionServiceProvider).hasAnyPillarGoalCompletion(uid, today);
    if (hasRecorded && context.mounted) {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Nuova analisi'),
          content: const Text(
            'Hai già registrato Sì o No su uno o più obiettivi di oggi. '
            'Rigenerando il piano perderai queste registrazioni. Continuare?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Annulla'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Continua'),
            ),
          ],
        ),
      );
      if (confirm != true) return;
    }
    if (!context.mounted) return;

    ref.read(_longevityPlanLoadingProvider.notifier).state = true;

    try {
      await loadLongevityPlan(ref);
    } catch (e) {
      if (context.mounted) showErrorDialog(context, e.toString());
    } finally {
      ref.read(_longevityPlanLoadingProvider.notifier).state = false;
    }
  }

  Future<void> _onPillarCompletion(
    BuildContext context,
    WidgetRef ref,
    LongevityPillar pillar,
    bool completed,
  ) async {
    final uid = ref.read(authNotifierProvider).user?.uid;
    if (uid == null) return;
    final dateStr = localCalendarDateKey();
    try {
      await ref.read(nutritionServiceProvider).setPillarGoalCompletion(
            uid,
            dateStr,
            pillar.name,
            completed,
          );
    } catch (e) {
      if (context.mounted) {
        showErrorDialog(context, 'Salvataggio non riuscito: $e');
      }
    }
  }

  Future<void> _onRefreshGarmin(String? uid) async {
    await refreshGarminSync(ref, uid, trigger: 'home_pull_to_refresh');
  }

  /// Tap su tile Alimentazione quando il piano AI è già stato generato.
  /// Apre lo stesso bottom sheet "Aggiungi pasto" della pagina Alimentazione,
  /// scegliendo il pasto in base all'ora (colazione/pranzo/cena/spuntino).
  Future<void> _onAddMealFromHome(BuildContext context) async {
    await showAddMealSheet(context, ref);
  }
}

final _longevityPlanLoadingProvider = StateProvider<bool>((ref) => false);
