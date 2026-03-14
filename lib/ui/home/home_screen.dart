import 'package:fitai_analyzer/providers/auth_notifier.dart';
import 'package:fitai_analyzer/providers/providers.dart';
import 'package:fitai_analyzer/services/gemini_api_key_service.dart';
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
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final packageAsync = ref.watch(longevityHomePackageProvider);
    final dailyGoals = ref.watch(dailyGoalsProvider);
    final weeklySprint = ref.watch(weeklySprintProvider);
    final strategicAdvice = ref.watch(strategicAdviceProvider);
    final isLoadingPlan = ref.watch(_longevityPlanLoadingProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Home'),
      ),
      body: packageAsync.when(
        data: (package) => CustomScrollView(
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
                      pillarContents: dailyGoals,
                      onGenerateTap: () => _onGeneratePlan(context, ref),
                    ),
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
                      onGenerateTap: () => _onGeneratePlan(context, ref),
                    ),
                    const SizedBox(height: 24),
                    LongevityPathSection(
                      baseline: package.baseline,
                      strategicAdvice: strategicAdvice,
                      isLoading: isLoadingPlan,
                      onGenerateTap: () => _onGeneratePlan(context, ref),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
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
        ),
      ),
    );
  }

  Future<void> _onGeneratePlan(BuildContext context, WidgetRef ref) async {
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
}

final _longevityPlanLoadingProvider = StateProvider<bool>((ref) => false);
