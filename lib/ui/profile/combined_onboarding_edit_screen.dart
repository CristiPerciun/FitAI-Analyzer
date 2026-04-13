import 'package:fitai_analyzer/providers/auth_notifier.dart';
import 'package:fitai_analyzer/providers/providers.dart'
    show nutritionMealPlanServiceProvider;
import 'package:fitai_analyzer/providers/user_profile_notifier.dart';
import 'package:fitai_analyzer/theme/app_theme.dart';
import 'package:fitai_analyzer/ui/onboarding/main_profile_single_page_fields.dart';
import 'package:fitai_analyzer/ui/onboarding/nutrition_goal_screen.dart';
import 'package:fitai_analyzer/ui/widgets/error_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Modifica da Impostazioni: onboarding principale + obiettivo mangiare in **un solo scroll**.
/// Salvataggio: prima `saveProfile`, poi `updateNutritionGoal`.
class CombinedOnboardingEditScreen extends ConsumerStatefulWidget {
  const CombinedOnboardingEditScreen({super.key});

  @override
  ConsumerState<CombinedOnboardingEditScreen> createState() =>
      _CombinedOnboardingEditScreenState();
}

class _CombinedOnboardingEditScreenState
    extends ConsumerState<CombinedOnboardingEditScreen> {
  final _formKey = GlobalKey<FormState>();
  final _mainKey = GlobalKey<MainProfileSinglePageFieldsState>();
  final _nutritionKey = GlobalKey<NutritionGoalScreenState>();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(userProfileNotifierProvider.notifier).loadProfile();
    });
  }

  Future<void> _saveAll() async {
    final mainState = _mainKey.currentState;
    final nutState = _nutritionKey.currentState;
    if (mainState == null || nutState == null) return;

    if (!mainState.validateAll()) return;
    if (!nutState.validateNutritionObjectiveSelection()) return;

    setState(() => _saving = true);
    try {
      final profileMain = mainState.buildMergedProfile();
      await ref.read(userProfileNotifierProvider.notifier).saveProfile(profileMain);
      if (!mounted) return;

      final goal = nutState.buildNutritionGoalModel();
      await ref.read(userProfileNotifierProvider.notifier).updateNutritionGoal(goal);
      if (!mounted) return;

      final uid = ref.read(authNotifierProvider).user?.uid;
      if (uid != null) {
        await ref.read(nutritionMealPlanServiceProvider).generateAndSave(uid);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profilo e obiettivo mangiare aggiornati.')),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) showErrorDialog(context, e.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final loading = ref.watch(userProfileNotifierProvider).isLoading;

    ref.listen(userProfileNotifierProvider, (prev, next) {
      if (next.error != null &&
          next.error!.isNotEmpty &&
          next.error != prev?.error &&
          context.mounted) {
        showErrorDialog(context, next.error!);
      }
    });

    return Stack(
      children: [
        Scaffold(
          appBar: AppBar(title: const Text('Modifica onboarding')),
          body: Column(
            children: [
              Expanded(
                child: Form(
                  key: _formKey,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 440),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            MainProfileSinglePageFields(key: _mainKey),
                            const Divider(height: 48, thickness: 1),
                            NutritionGoalScreen(
                              key: _nutritionKey,
                              presentation:
                                  NutritionGoalPresentation.singleScrollColumn,
                            ),
                            const Divider(height: 48, thickness: 1),
                            Text(
                              'Obiettivo allenamento',
                              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Qui potrai definire obiettivi di forza, volume e recupero '
                              '(separati dall’obiettivo mangiare). Sezione in arrivo.',
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color:
                                        Theme.of(context).colorScheme.onSurfaceVariant,
                                    height: 1.35,
                                  ),
                            ),
                            const SizedBox(height: 24),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                child: FilledButton(
                  onPressed: (loading || _saving) ? null : _saveAll,
                  child: (loading || _saving)
                      ? const SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.white,
                          ),
                        )
                      : const Text('Salva tutto'),
                ),
              ),
            ],
          ),
        ),
        if (_saving) ...[
          const ModalBarrier(dismissible: false, color: Color(0x66000000)),
          Center(
            child: Material(
              color: Theme.of(context).colorScheme.surface,
              elevation: 6,
              borderRadius: BorderRadius.circular(16),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(
                      width: 40,
                      height: 40,
                      child: CircularProgressIndicator(),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Salvataggio e generazione piano pasti…',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}
