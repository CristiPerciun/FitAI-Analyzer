import 'package:fitai_analyzer/models/longevity_home_package.dart';
import 'package:fitai_analyzer/providers/auth_notifier.dart';
import 'package:fitai_analyzer/providers/garmin_sync_notifier.dart';
import 'package:fitai_analyzer/providers/providers.dart';
import 'package:fitai_analyzer/services/gemini_api_key_service.dart';
import 'package:fitai_analyzer/utils/boot_log.dart';
import 'package:fitai_analyzer/ui/home/widgets/garmin_daily_stats.dart';
import 'package:fitai_analyzer/ui/home/widgets/longevity_header.dart';
import 'package:fitai_analyzer/ui/home/widgets/longevity_path_section.dart';
import 'package:fitai_analyzer/ui/home/widgets/pillar_grid.dart';
import 'package:fitai_analyzer/ui/home/widgets/weekly_sprint_card.dart';
import 'package:fitai_analyzer/ui/widgets/error_dialog.dart';
import 'package:fitai_analyzer/ui/widgets/gemini_api_key_dialog.dart';
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

    final uid = ref.watch(authNotifierProvider).user?.uid;
    final packageAsync = ref.watch(longevityHomePackageProvider);
    final planDay = ref.watch(homeLongevityPlanForUiProvider);
    final dailyGoals = ref.watch(homeDailyGoalsMapProvider);
    final weeklySprint = planDay?.weeklySprint;
    final strategicAdvice = planDay?.strategicAdvice;
    final isLoadingPlan = ref.watch(_longevityPlanLoadingProvider);
    final isGarminSyncing =
        ref.watch(garminSyncNotifierProvider.select((s) => s.isSyncing));

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
                            const SizedBox(height: 12),
                            PillarGrid(
                              isLoading: isLoadingPlan,
                              pillarContents:
                                  dailyGoals.isEmpty ? null : dailyGoals,
                              onGenerateTap: () => _onGeneratePlan(context),
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

  Future<void> _onGeneratePlan(BuildContext context) async {
    final ref = this.ref;
    final uid = ref.read(authNotifierProvider).user?.uid;
    if (uid == null) {
      if (context.mounted) showErrorDialog(context, 'Utente non autenticato.');
      return;
    }

    final apiKeyService = ref.read(geminiApiKeyServiceProvider);
    if (!await apiKeyService.hasValidKey()) {
      if (!context.mounted) return;
      final saved = await showGeminiApiKeyDialog(context, ref);
      if (!saved || !context.mounted) return;
    }

    ref.read(_longevityPlanLoadingProvider.notifier).state = true;

    try {
      await loadLongevityPlan(ref);
    } catch (e) {
      if (context.mounted) showErrorDialog(context, e.toString());
    } finally {
      ref.read(_longevityPlanLoadingProvider.notifier).state = false;
    }
  }

  Future<void> _onRefreshGarmin(String? uid) async {
    await refreshGarminSync(ref, uid, trigger: 'home_pull_to_refresh');
  }
}

final _longevityPlanLoadingProvider = StateProvider<bool>((ref) => false);
