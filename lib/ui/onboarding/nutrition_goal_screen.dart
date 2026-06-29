import 'package:fitai_analyzer/providers/async_action_notifier.dart';
import 'package:fitai_analyzer/providers/auth_notifier.dart';
import 'package:fitai_analyzer/providers/nutrition_goal_form_provider.dart';
import 'package:fitai_analyzer/providers/providers.dart'
    show nutritionMealPlanServiceProvider;
import 'package:fitai_analyzer/providers/user_profile_notifier.dart';
import 'package:fitai_analyzer/theme/app_theme.dart';
import 'package:fitai_analyzer/ui/widgets/custom_slider.dart';
import 'package:fitai_analyzer/ui/widgets/dropdown_with_search.dart';
import 'package:fitai_analyzer/ui/widgets/error_dialog.dart';
import 'package:fitai_analyzer/ui/widgets/multi_select_chip.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Creazione guidata (4 pagine) vs modifica da Impostazioni (tutto in un blocco scrollabile).
enum NutritionGoalPresentation {
  wizard,
  singleScrollColumn,
}

/// Indice pagina del wizard "Obiettivo mangiare" (0–3). AutoDispose: si azzera
/// all'uscita dalla schermata.
final nutritionGoalPageProvider = StateProvider.autoDispose<int>((ref) => 0);

const _nutritionObjectiveOptions = <(String key, String label)>[
  ('perdita_grasso', 'Perdita grasso / definizione'),
  ('ipertrofia', 'Ipertrofia / massa muscolare'),
  ('mantenimento', 'Mantenimento'),
  ('ricomposizione', 'Ricomposizione corporea'),
  ('performance', 'Performance / forza'),
];

const _stylePairs = <(String key, String label)>[
  ('mediterraneo', 'Mediterraneo'),
  ('alto_proteine', 'Alto proteine'),
  ('low_carb', 'Low carb'),
  ('plant_based', 'Plant-based'),
  ('zona', 'Zona / bilanciato'),
  ('flessibile', 'Flessibile (IIFYM-style)'),
];

/// Sub-onboarding «Obiettivo Mangiare» (10 domande in 4 sezioni).
///
/// Lo stato del form vive in [nutritionGoalFormProvider]; qui restano il
/// `PageController` del wizard e il `TextEditingController` delle note.
/// Se [onSuccess] è valorizzato (es. apertura da Alimentazione), viene chiamato
/// al posto di [context.go] così resti sulla schermata corrente.
class NutritionGoalScreen extends ConsumerStatefulWidget {
  const NutritionGoalScreen({
    super.key,
    this.onSuccess,
    this.onBackFromFirstPage,
    this.hideAppBar = false,
    this.presentation = NutritionGoalPresentation.wizard,
  });

  /// Esegui al salvataggio riuscito (es. `Navigator.pop(context)`).
  final VoidCallback? onSuccess;

  /// Wizard: alla prima pagina, back opzionale verso step precedente.
  final VoidCallback? onBackFromFirstPage;

  /// Wizard: AppBar interna disattivata (flussi con AppBar esterna).
  final bool hideAppBar;

  /// [wizard] = prima creazione (pagine). [singleScrollColumn] = modifica da Impostazioni (blocco unico).
  final NutritionGoalPresentation presentation;

  @override
  ConsumerState<NutritionGoalScreen> createState() =>
      _NutritionGoalScreenState();
}

class _NutritionGoalScreenState extends ConsumerState<NutritionGoalScreen> {
  PageController? _pageController;
  static const _totalPages = 4;
  bool _seeded = false;

  final _extraNotesController = TextEditingController();

  static final _fuoriOptions = [
    MultiSelectOption(id: 'mai', label: 'Quasi mai'),
    MultiSelectOption(id: '1_2_sett', label: '1–2 volte / sett.'),
    MultiSelectOption(id: '3_5_sett', label: '3–5 volte / sett.'),
    MultiSelectOption(id: 'quotidiano', label: 'Quasi ogni giorno'),
  ];

  static final _allergieOptions = [
    MultiSelectOption(id: 'lattosio', label: 'Lattosio'),
    MultiSelectOption(id: 'glutine', label: 'Glutine'),
    MultiSelectOption(id: 'noci', label: 'Frutta a guscio'),
    MultiSelectOption(id: 'crostacei', label: 'Crostacei'),
    MultiSelectOption(id: 'uova', label: 'Uova'),
    MultiSelectOption(id: 'soia', label: 'Soia'),
  ];

  static final _esclusioniOptions = [
    MultiSelectOption(id: 'vegetariano', label: 'Vegetariano'),
    MultiSelectOption(id: 'vegano', label: 'Vegano'),
    MultiSelectOption(id: 'no_maiale', label: 'No maiale'),
    MultiSelectOption(id: 'no_alcol', label: 'No alcol'),
    MultiSelectOption(id: 'no_zuccheri_raffinati', label: 'No zuccheri raffinati'),
  ];

  @override
  void initState() {
    super.initState();
    if (widget.presentation == NutritionGoalPresentation.wizard) {
      _pageController = PageController();
    }
  }

  @override
  void dispose() {
    _pageController?.dispose();
    _extraNotesController.dispose();
    super.dispose();
  }

  String _sectionTitleFor(int pageIndex) {
    switch (pageIndex) {
      case 0:
        return 'Abitudini attuali';
      case 1:
        return 'Preferenze e restrizioni';
      case 2:
        return 'Obiettivo mangiare';
      default:
        return 'Extra';
    }
  }

  Future<void> _submit() async {
    final ok =
        await ref.read(nutritionGoalFlowActionProvider.notifier).run(() async {
      final goal = ref.read(nutritionGoalFormProvider.notifier).buildModel();
      await ref
          .read(userProfileNotifierProvider.notifier)
          .updateNutritionGoal(goal);
      final uid = ref.read(currentUidProvider);
      if (uid != null) {
        await ref.read(nutritionMealPlanServiceProvider).generateAndSave(uid);
      }
    });
    if (!mounted || !ok) return;
    final cb = widget.onSuccess;
    if (cb != null) {
      cb();
    } else {
      context.go('/');
    }
  }

  void _nextPage() {
    final pc = _pageController;
    if (pc == null) return;
    final i = ref.read(nutritionGoalPageProvider);
    if (i < _totalPages - 1) {
      pc.nextPage(
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
      );
    } else {
      _submit();
    }
  }

  void _prevPage() {
    final pc = _pageController;
    final i = ref.read(nutritionGoalPageProvider);
    if (i > 0 && pc != null) {
      pc.previousPage(
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
      );
    } else if (mounted) {
      final back = widget.onBackFromFirstPage;
      if (back != null) {
        back();
      } else {
        context.pop();
      }
    }
  }

  bool _validatePage() {
    final i = ref.read(nutritionGoalPageProvider);
    if (i == 2) {
      final ok = ref.read(nutritionGoalFormProvider.notifier).validateObjective();
      if (!ok) showErrorDialog(context, 'Seleziona un obiettivo nutrizionale');
      return ok;
    }
    return true;
  }

  Widget _buildSingleScrollColumn(
    List<String> styleLabels,
    Map<String, String> keyForStyleLabel,
  ) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Obiettivo mangiare',
          style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(
          'Abitudini attuali',
          style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        _columnSection1(),
        const Divider(height: 40, thickness: 1),
        Text(
          'Preferenze e restrizioni',
          style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        _columnSection2(),
        const Divider(height: 40, thickness: 1),
        Text(
          'Obiettivo nutrizionale e stile',
          style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        _columnSection3(styleLabels, keyForStyleLabel),
        const Divider(height: 40, thickness: 1),
        Text(
          'Proteine, carboidrati, integratori, note',
          style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        _columnSection4(),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(userProfileNotifierProvider).profile;
    final loading = ref.watch(userProfileNotifierProvider).isLoading;

    // Seed una sola volta dal profilo caricato.
    if (profile != null && !_seeded) {
      _seeded = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ref.read(nutritionGoalFormProvider.notifier).seedFrom(profile);
        _extraNotesController.text =
            ref.read(nutritionGoalFormProvider).extraNotesText;
      });
    }

    ref.listen(userProfileNotifierProvider, (prev, next) {
      if (next.error != null &&
          next.error!.isNotEmpty &&
          next.error != prev?.error &&
          context.mounted) {
        showErrorDialog(context, next.error!);
      }
    });

    ref.listen(nutritionGoalFlowActionProvider, (prev, next) {
      if (next.hasError && context.mounted) {
        showErrorDialog(context, next.error.toString());
      }
    });

    if (profile == null) {
      if (widget.presentation == NutritionGoalPresentation.singleScrollColumn) {
        return const Padding(
          padding: EdgeInsets.all(24),
          child: Text('Carica il profilo principale prima di modificare l’alimentazione.'),
        );
      }
      return Scaffold(
        appBar: AppBar(title: const Text('Obiettivo mangiare')),
        body: const Center(
          child: Text('Carica prima il profilo principale dall’onboarding.'),
        ),
      );
    }

    final styleLabels = _stylePairs.map((e) => e.$2).toList();
    final keyForStyleLabel = Map<String, String>.fromEntries(
      _stylePairs.map((e) => MapEntry(e.$2, e.$1)),
    );

    if (widget.presentation == NutritionGoalPresentation.singleScrollColumn) {
      return _buildSingleScrollColumn(styleLabels, keyForStyleLabel);
    }

    final pageIndex = ref.watch(nutritionGoalPageProvider);
    final flowBusy = ref.watch(nutritionGoalFlowActionProvider).isLoading;
    final busy = loading || flowBusy;

    return Stack(
      children: [
        Scaffold(
          appBar: widget.hideAppBar
              ? null
              : AppBar(
                  title: Text(_sectionTitleFor(pageIndex)),
                  leading: IconButton(
                    icon: const Icon(Icons.arrow_back),
                    onPressed: busy ? null : _prevPage,
                  ),
                  bottom: PreferredSize(
                    preferredSize: const Size.fromHeight(4),
                    child: LinearProgressIndicator(
                      value: (pageIndex + 1) / _totalPages,
                      backgroundColor:
                          Theme.of(context).colorScheme.surfaceContainerHighest,
                    ),
                  ),
                ),
          body: Column(
            children: [
              if (widget.hideAppBar) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
                  child: Text(
                    _sectionTitleFor(pageIndex),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ),
                LinearProgressIndicator(
                  value: (pageIndex + 1) / _totalPages,
                  backgroundColor:
                      Theme.of(context).colorScheme.surfaceContainerHighest,
                ),
                const SizedBox(height: 8),
              ],
              Expanded(
                child: PageView(
                  controller: _pageController!,
                  onPageChanged: (i) =>
                      ref.read(nutritionGoalPageProvider.notifier).state = i,
                  children: [
                    _buildSection1(),
                    _buildSection2(),
                    _buildSection3(styleLabels, keyForStyleLabel),
                    _buildSection4(),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(24),
                child: Row(
                  children: [
                    if (pageIndex > 0)
                      TextButton(
                        onPressed: busy ? null : _prevPage,
                        child: const Text('Indietro'),
                      )
                    else if (widget.onBackFromFirstPage != null)
                      TextButton(
                        onPressed: busy ? null : _prevPage,
                        child: const Text('Indietro'),
                      ),
                    const Spacer(),
                    FilledButton(
                      onPressed: busy
                          ? null
                          : () {
                              if (!_validatePage()) return;
                              _nextPage();
                            },
                      child: busy
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.white,
                              ),
                            )
                          : Text(
                              pageIndex == _totalPages - 1
                                  ? 'Salva obiettivo'
                                  : 'Continua',
                            ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (flowBusy) ...[
          const ModalBarrier(dismissible: false, color: Color(0x66000000)),
          Center(
            child: Material(
              color: Theme.of(context).colorScheme.surface,
              elevation: 6,
              borderRadius: BorderRadius.circular(16),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
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
                      'Aggiornamento profilo e generazione piano pasti…',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'L’intelligenza artificiale può richiedere qualche secondo.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
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

  Widget _columnSection1() {
    final form = ref.watch(nutritionGoalFormProvider);
    final notifier = ref.read(nutritionGoalFormProvider.notifier);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '1. Quanti pasti principali fai di solito al giorno?',
          style: Theme.of(context).textTheme.bodyLarge,
        ),
        const SizedBox(height: 8),
        CustomSlider(
          label: 'Pasti / giorno',
          value: form.mealsPerDay,
          min: 2,
          max: 6,
          divisions: 4,
          valueLabel: (v) => '${v.round()}',
          onChanged: notifier.setMealsPerDay,
        ),
        const SizedBox(height: 24),
        Text(
          '2. Per te è importante rispettare orari fissi dei pasti?',
          style: Theme.of(context).textTheme.bodyLarge,
        ),
        const SizedBox(height: 8),
        SwitchListTile(
          title: const Text('Timing dei pasti importante'),
          value: form.timingImportante,
          onChanged: notifier.setTimingImportante,
        ),
        const SizedBox(height: 16),
        MultiSelectChipGroup(
          title: '3. Con che frequenza mangi fuori casa o ordini delivery?',
          options: _fuoriOptions,
          selected: form.fuoriCasa,
          onChanged: notifier.setFuoriCasa,
        ),
      ],
    );
  }

  Widget _columnSection2() {
    final form = ref.watch(nutritionGoalFormProvider);
    final notifier = ref.read(nutritionGoalFormProvider.notifier);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        MultiSelectChipGroup(
          title: '4. Allergie o intolleranze da considerare',
          options: _allergieOptions,
          selected: form.allergie,
          onChanged: notifier.setAllergie,
        ),
        const SizedBox(height: 24),
        MultiSelectChipGroup(
          title: '5. Preferenze o alimenti da escludere',
          options: _esclusioniOptions,
          selected: form.esclusioni,
          onChanged: notifier.setEsclusioni,
        ),
      ],
    );
  }

  Widget _columnSection3(
    List<String> styleLabels,
    Map<String, String> keyForStyleLabel,
  ) {
    final form = ref.watch(nutritionGoalFormProvider);
    final notifier = ref.read(nutritionGoalFormProvider.notifier);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '6. Obiettivo nutrizionale (non è il main goal a 4 vie)',
          style: Theme.of(context).textTheme.bodyLarge,
        ),
        const SizedBox(height: 8),
        Text(
          'Pre-selezionato in base al tuo main goal; puoi modificarlo.',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _nutritionObjectiveOptions.map((e) {
            return ChoiceChip(
              label: Text(e.$2),
              selected: form.nutritionObjective == e.$1,
              onSelected: (_) => notifier.setNutritionObjective(e.$1),
            );
          }).toList(),
        ),
        const SizedBox(height: 20),
        Text(
          '7. Velocità di avvicinamento al target',
          style: Theme.of(context).textTheme.bodyLarge,
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ('lenta', 'Lenta'),
            ('media', 'Media'),
            ('aggressiva', 'Aggressiva'),
          ].map((e) {
            return ChoiceChip(
              label: Text(e.$2),
              selected: form.speed == e.$1,
              onSelected: (_) => notifier.setSpeed(e.$1),
            );
          }).toList(),
        ),
        const SizedBox(height: 20),
        Text(
          '8. Stile alimentare preferito',
          style: Theme.of(context).textTheme.bodyLarge,
        ),
        const SizedBox(height: 8),
        DropdownWithSearch(
          label: 'Stile',
          options: styleLabels,
          value: _stylePairs
              .firstWhere((e) => e.$1 == form.styleKey,
                  orElse: () => _stylePairs.first)
              .$2,
          hint: 'Cerca o scegli…',
          onChanged: (label) {
            if (label != null) {
              notifier.setStyleKey(keyForStyleLabel[label] ?? form.styleKey);
            }
          },
        ),
      ],
    );
  }

  Widget _columnSection4() {
    final form = ref.watch(nutritionGoalFormProvider);
    final notifier = ref.read(nutritionGoalFormProvider.notifier);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '9. Quanto vuoi puntare sulle proteine?',
          style: Theme.of(context).textTheme.bodyLarge,
        ),
        const SizedBox(height: 6),
        Text(
          'Scegli la risposta più vicina a te: l’app tradurrà in un target tecnico per l’AI.',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
        const SizedBox(height: 12),
        ...[
          ('leggero', 'Normale / poco sport'),
          ('standard', 'Un po’ più di proteine (stile quotidiano sano)'),
          ('allenamento', 'Mi alleno regolarmente'),
          ('massa', 'Voglio massa o definizione “da palestra”'),
        ].map((e) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: ChoiceChip(
              label: Text(e.$2),
              selected: form.proteinLevel == e.$1,
              onSelected: (_) => notifier.setProteinLevel(e.$1),
            ),
          );
        }),
        const SizedBox(height: 20),
        Text(
          '10. Come ti piace mangiare i carboidrati?',
          style: Theme.of(context).textTheme.bodyLarge,
        ),
        const SizedBox(height: 6),
        Text(
          'Niente percentuali: solo la tendenza (pasta/pane vs più proteine e grassi).',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ('equilibrato', 'Equilibrato'),
            ('piu_carb', 'Amo pasta, pane, riso'),
            ('meno_carb', 'Preferisco meno carb, più grassi'),
          ].map((e) {
            return ChoiceChip(
              label: Text(e.$2),
              selected: form.carbStyle == e.$1,
              onSelected: (_) => notifier.setCarbStyle(e.$1),
            );
          }).toList(),
        ),
        const SizedBox(height: 28),
        Text(
          '11. Integratori',
          style: Theme.of(context).textTheme.bodyLarge,
        ),
        const SizedBox(height: 4),
        Text(
          'Vuoi che i piani considerino integratori (proteine in polvere, creatina, omega-3, ecc.)?',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Sì, includi integratori dove ha senso evidenza-based'),
          value: form.useSupplements,
          onChanged: notifier.setUseSupplements,
        ),
        const SizedBox(height: 16),
        Text(
          '12. Note libere',
          style: Theme.of(context).textTheme.bodyLarge,
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _extraNotesController,
          decoration: const InputDecoration(
            hintText:
                'Es. niente pesce, tanta pasta a pranzo, colazione dolce, preferenze famiglia…',
            border: OutlineInputBorder(),
            alignLabelWithHint: true,
          ),
          maxLines: 4,
          textCapitalization: TextCapitalization.sentences,
          onChanged: notifier.setExtraNotesText,
        ),
      ],
    );
  }

  Widget _buildSection1() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: _columnSection1(),
    );
  }

  Widget _buildSection2() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: _columnSection2(),
    );
  }

  Widget _buildSection3(
    List<String> styleLabels,
    Map<String, String> keyForStyleLabel,
  ) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: _columnSection3(styleLabels, keyForStyleLabel),
    );
  }

  Widget _buildSection4() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: _columnSection4(),
    );
  }
}
