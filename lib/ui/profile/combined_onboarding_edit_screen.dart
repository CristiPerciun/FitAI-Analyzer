import 'package:fitai_analyzer/providers/async_action_notifier.dart';
import 'package:fitai_analyzer/providers/auth_notifier.dart';
import 'package:fitai_analyzer/providers/main_profile_form_provider.dart';
import 'package:fitai_analyzer/providers/nutrition_goal_form_provider.dart';
import 'package:fitai_analyzer/providers/providers.dart'
    show nutritionMealPlanServiceProvider;
import 'package:fitai_analyzer/providers/user_profile_notifier.dart';
import 'package:fitai_analyzer/theme/app_card_theme.dart';
import 'package:fitai_analyzer/ui/onboarding/main_profile_single_page_fields.dart';
import 'package:fitai_analyzer/ui/onboarding/nutrition_goal_screen.dart';
import 'package:fitai_analyzer/ui/widgets/design/design.dart';
import 'package:fitai_analyzer/ui/widgets/error_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Modifica da Impostazioni: onboarding principale + obiettivo mangiare in **un solo scroll**.
/// Lo stato dei due form vive in [mainProfileFormProvider] / [nutritionGoalFormProvider];
/// il salvataggio legge i notifier (niente più GlobalKey verso i figli).
///
/// Redesign: i form condivisi restano invariati ma vengono raggruppati in
/// pannelli morbidi ([FitSoftCard]) con header "hero", input arrotondati e una
/// barra di salvataggio fissa a pillola. Lo stile input è applicato solo qui
/// tramite un [Theme] locale: nessun impatto sul flusso di onboarding globale.
class CombinedOnboardingEditScreen extends ConsumerStatefulWidget {
  const CombinedOnboardingEditScreen({super.key});

  @override
  ConsumerState<CombinedOnboardingEditScreen> createState() =>
      _CombinedOnboardingEditScreenState();
}

class _CombinedOnboardingEditScreenState
    extends ConsumerState<CombinedOnboardingEditScreen> {
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(userProfileNotifierProvider.notifier).loadProfile();
    });
  }

  Future<void> _saveAll() async {
    final mainState = ref.read(mainProfileFormProvider);
    final mainN = ref.read(mainProfileFormProvider.notifier);
    final nutN = ref.read(nutritionGoalFormProvider.notifier);

    // Stesso ordine di validazione dell'originale validateAll().
    if (mainState.mainGoal == null) {
      showErrorDialog(context, 'Seleziona l\'obiettivo principale');
      return;
    }
    final formState = _formKey.currentState;
    if (formState != null && !formState.validate()) return;
    if (mainState.gender == null) {
      showErrorDialog(context, 'Seleziona il sesso biologico');
      return;
    }
    if (mainState.trainingDaysPerWeek == null) {
      showErrorDialog(context, 'Seleziona i giorni di allenamento');
      return;
    }
    if (mainState.equipment == null) {
      showErrorDialog(context, 'Seleziona l\'attrezzatura');
      return;
    }
    if (!nutN.validateObjective()) {
      showErrorDialog(context, 'Seleziona un obiettivo nutrizionale');
      return;
    }

    String? snackMsg;
    final ok = await ref.read(combinedSaveActionProvider.notifier).run(() async {
      // Profilo principale + obiettivo nutrizione in UN UNICO oggetto, scritto
      // con una sola set(merge) atomica: niente più salvataggi parziali.
      final merged = mainN.buildMergedProfile().copyWith(
        nutritionGoal: nutN.buildModel(),
      );
      await ref
          .read(userProfileNotifierProvider.notifier)
          .saveCombinedOnboarding(merged);

      // Generazione piano pasti AI: best-effort. Il profilo è già salvato, quindi
      // un errore qui non deve presentarsi come "salvataggio fallito".
      final uid = ref.read(currentUidProvider);
      var mealPlanFailed = false;
      if (uid != null) {
        try {
          await ref.read(nutritionMealPlanServiceProvider).generateAndSave(uid);
        } catch (_) {
          mealPlanFailed = true;
        }
      }
      snackMsg = mealPlanFailed
          ? 'Profilo salvato. Piano pasti non rigenerato: riprova più tardi.'
          : 'Profilo e obiettivo mangiare aggiornati.';
    });

    if (!mounted || !ok) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(snackMsg ?? 'Profilo e obiettivo mangiare aggiornati.'),
      ),
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final loading = ref.watch(userProfileNotifierProvider).isLoading;
    final saving = ref.watch(combinedSaveActionProvider).isLoading;

    ref.listen(userProfileNotifierProvider, (prev, next) {
      if (next.error != null &&
          next.error!.isNotEmpty &&
          next.error != prev?.error &&
          context.mounted) {
        showErrorDialog(context, next.error!);
      }
    });

    ref.listen(combinedSaveActionProvider, (prev, next) {
      if (next.hasError && context.mounted) {
        showErrorDialog(context, next.error.toString());
      }
    });

    return Stack(
      children: [
        Scaffold(
          appBar: AppBar(
            leadingWidth: 64,
            leading: _BackButton(),
            title: const SizedBox.shrink(),
          ),
          body: Theme(
            // Stile input morbido limitato a questa schermata.
            data: theme.copyWith(
              inputDecorationTheme: softInputDecorationTheme(context),
            ),
            child: Column(
              children: [
                Expanded(
                  child: Form(
                    key: _formKey,
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 480),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const _OnboardingHeroCard(),
                              const SizedBox(height: 16),
                              const FitSoftCard(
                                child: MainProfileSinglePageFields(),
                              ),
                              const SizedBox(height: 16),
                              const FitSoftCard(
                                child: NutritionGoalScreen(
                                  presentation: NutritionGoalPresentation
                                      .singleScrollColumn,
                                ),
                              ),
                              const SizedBox(height: 16),
                              const _TrainingPlaceholderCard(),
                              const SizedBox(height: 8),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                _SaveBar(busy: loading || saving, onSave: _saveAll),
              ],
            ),
          ),
        ),
        if (saving) ...[
          const ModalBarrier(dismissible: false, color: Color(0x66000000)),
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 320),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: FitSoftCard(
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
                        style: theme.textTheme.titleSmall,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// Header "hero" charcoal con titolo schermata e badge delle sezioni.
class _OnboardingHeroCard extends StatelessWidget {
  const _OnboardingHeroCard();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final card = theme.extension<AppCardTheme>()!;
    return FitHeroCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Modifica onboarding',
            style: theme.textTheme.headlineMedium?.copyWith(
              color: card.contentColor,
              fontWeight: FontWeight.w700,
              fontSize: 26,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Aggiorna profilo e obiettivo mangiare: l\'AI rigenera il tuo piano.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: card.contentColorMuted,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 14),
          const Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FitBadgePill(
                label: 'Profilo',
                leadingIcon: Icons.person_outline,
                onHeroSurface: true,
              ),
              FitBadgePill(
                label: 'Obiettivo mangiare',
                leadingIcon: Icons.restaurant_outlined,
                onHeroSurface: true,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Sezione "Obiettivo allenamento" — placeholder in arrivo.
class _TrainingPlaceholderCard extends StatelessWidget {
  const _TrainingPlaceholderCard();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return FitSoftCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              FitIconBadge(icon: Icons.fitness_center, size: 44),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  'Obiettivo allenamento',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const FitBadgePill(
                label: 'In arrivo',
                variant: FitBadgeVariant.outline,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Qui potrai definire obiettivi di forza, volume e recupero '
            '(separati dall\'obiettivo mangiare). Sezione in arrivo.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: cs.onSurfaceVariant,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}

/// Barra inferiore fissa con il pulsante primario "Salva tutto".
class _SaveBar extends StatelessWidget {
  const _SaveBar({required this.busy, required this.onSave});

  final bool busy;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final shadowColor =
        theme.extension<AppCardTheme>()?.softShadowColor ??
        Colors.black.withValues(alpha: 0.06);
    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        boxShadow: [
          BoxShadow(
            color: shadowColor,
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: FilledButton(
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(54),
              shape: const StadiumBorder(),
              backgroundColor: cs.primary,
              foregroundColor: cs.onPrimary,
              textStyle: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            onPressed: busy ? null : onSave,
            child: busy
                ? SizedBox(
                    height: 22,
                    width: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: cs.onPrimary,
                    ),
                  )
                : const Text('Salva tutto'),
          ),
        ),
      ),
    );
  }
}

/// Pulsante "indietro" circolare in AppBar (stile design di riferimento).
class _BackButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 8),
      child: Center(
        child: FitCircleIconButton(
          icon: Icons.arrow_back,
          tooltip: 'Indietro',
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ),
    );
  }
}
