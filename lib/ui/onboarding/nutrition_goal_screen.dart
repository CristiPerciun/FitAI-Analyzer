import 'package:fitai_analyzer/models/user_profile.dart';
import 'package:fitai_analyzer/providers/auth_notifier.dart';
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

/// Mappa i 4 [UserProfile.mainGoal] → pre-selezione [NutritionGoal.nutritionObjective].
String mapAppMainToNutritionObjective(String mainGoal) {
  switch (mainGoal) {
    case 'weight_loss':
      return 'perdita_grasso';
    case 'muscle_gain':
      return 'ipertrofia';
    case 'strength':
      return 'performance';
    case 'longevity':
    default:
      return 'mantenimento';
  }
}

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
  NutritionGoalScreenState createState() => NutritionGoalScreenState();
}

class NutritionGoalScreenState extends ConsumerState<NutritionGoalScreen> {
  PageController? _pageController;
  int _pageIndex = 0;
  static const _totalPages = 4;
  bool _seeded = false;
  /// Copre salvataggio profilo, aggregazione e generazione piano pasti IA.
  bool _flowBusy = false;

  // Sezione 1 — abitudini (1–3)
  double _mealsPerDay = 3;
  bool _timingImportante = false;
  final Set<String> _fuoriCasa = {};

  // Sezione 2 — preferenze (4–5)
  final Set<String> _allergie = {};
  final Set<String> _esclusioni = {};

  // Sezione 3 — obiettivo (6–8)
  String _nutritionObjective = 'mantenimento';
  String _speed = 'media';
  String _styleKey = 'mediterraneo';

  // Sezione 4 — extra (9–12): scelte semplici (niente calcoli g/kg o %)
  /// `leggero` | `standard` | `allenamento` | `massa`
  String _proteinLevel = 'standard';
  /// `equilibrato` | `piu_carb` | `meno_carb`
  String _carbStyle = 'equilibrato';
  bool _useSupplements = false;
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

  void _seedFromProfile(UserProfile? p) {
    if (p == null || _seeded) return;
    _seeded = true;
    final existing = p.nutritionGoal;
    if (existing != null) {
      _nutritionObjective = existing.nutritionObjective;
      _speed = existing.speed;
      _styleKey = existing.style;
      _mealsPerDay = existing.mealsPerDay.toDouble();
      _timingImportante = existing.timingImportante;
      _seedProteinLevelFromGrams(existing.proteinGramsPerKg);
      _seedCarbStyleFromPercent(existing.carbsPercentage);
      _useSupplements = existing.useSupplements;
      _extraNotesController.text = existing.extraNotes;
      _fuoriCasa
        ..clear()
        ..addAll(
          existing.preferences
              .where((e) => e.startsWith('fuori:'))
              .map((e) => e.split(':').last),
        );
      _allergie
        ..clear()
        ..addAll(
          existing.preferences
              .where((e) => e.startsWith('allergia:'))
              .map((e) => e.split(':').last),
        );
      _esclusioni
        ..clear()
        ..addAll(
          existing.preferences
              .where((e) => e.startsWith('escludi:'))
              .map((e) => e.split(':').last),
        );
    } else {
      _nutritionObjective = mapAppMainToNutritionObjective(p.mainGoal);
    }
  }

  void _seedProteinLevelFromGrams(double g) {
    const tiers = [1.6, 1.8, 2.0, 2.2];
    const keys = ['leggero', 'standard', 'allenamento', 'massa'];
    var best = 0;
    for (var i = 1; i < 4; i++) {
      if ((g - tiers[i]).abs() < (g - tiers[best]).abs()) best = i;
    }
    _proteinLevel = keys[best];
  }

  void _seedCarbStyleFromPercent(int carbs) {
    if (carbs >= 48) {
      _carbStyle = 'piu_carb';
    } else if (carbs <= 40) {
      _carbStyle = 'meno_carb';
    } else {
      _carbStyle = 'equilibrato';
    }
  }

  /// Decimi g/kg (16–22) da livello scelto.
  int get _proteinDeciFromLevel {
    switch (_proteinLevel) {
      case 'leggero':
        return 16;
      case 'allenamento':
        return 20;
      case 'massa':
        return 22;
      case 'standard':
      default:
        return 18;
    }
  }

  /// (carbs %, fat %) indicativi per AI / modello.
  (int carbs, int fat) get _macroSplitFromCarbStyle {
    switch (_carbStyle) {
      case 'piu_carb':
        return (50, 28);
      case 'meno_carb':
        return (38, 37);
      case 'equilibrato':
      default:
        return (45, 32);
    }
  }

  String get _sectionTitle {
    switch (_pageIndex) {
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

  /// Costruisce il modello senza salvare (es. salvataggio combinato da Impostazioni).
  NutritionGoal buildNutritionGoalModel() {
    final prefs = <String>[
      ..._fuoriCasa.map((e) => 'fuori:$e'),
      ..._allergie.map((e) => 'allergia:$e'),
      ..._esclusioni.map((e) => 'escludi:$e'),
    ];
    final proteinDeci = _proteinDeciFromLevel;
    final macro = _macroSplitFromCarbStyle;
    return NutritionGoal(
      nutritionObjective: _nutritionObjective,
      calorieTarget: 0,
      proteinGPerKg: proteinDeci,
      carbsPercentage: macro.$1,
      fatPercentage: macro.$2,
      speed: _speed,
      mealsPerDay: _mealsPerDay.round().clamp(2, 6),
      timingImportante: _timingImportante,
      style: _styleKey,
      preferences: prefs,
      useSupplements: _useSupplements,
      extraNotes: _extraNotesController.text.trim(),
    );
  }

  /// Validazione obiettivo nutrizionale (chiamata prima del salvataggio esterno).
  bool validateNutritionObjectiveSelection() {
    if (!_nutritionObjectiveOptions.any((e) => e.$1 == _nutritionObjective)) {
      showErrorDialog(context, 'Seleziona un obiettivo nutrizionale');
      return false;
    }
    return true;
  }

  Future<void> _submit() async {
    final goal = buildNutritionGoalModel();

    setState(() => _flowBusy = true);
    try {
      await ref.read(userProfileNotifierProvider.notifier).updateNutritionGoal(goal);
      if (!mounted) return;
      final uid = ref.read(authNotifierProvider).user?.uid;
      if (uid != null) {
        await ref.read(nutritionMealPlanServiceProvider).generateAndSave(uid);
      }
      if (!mounted) return;
      final cb = widget.onSuccess;
      if (cb != null) {
        cb();
      } else {
        context.go('/');
      }
    } catch (e) {
      if (mounted) showErrorDialog(context, e.toString());
    } finally {
      if (mounted) setState(() => _flowBusy = false);
    }
  }

  void _nextPage() {
    final pc = _pageController;
    if (pc == null) return;
    if (_pageIndex < _totalPages - 1) {
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
    if (_pageIndex > 0 && pc != null) {
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
    if (_pageIndex == 2) {
      return validateNutritionObjectiveSelection();
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
    _seedFromProfile(profile);

    ref.listen(userProfileNotifierProvider, (prev, next) {
      if (next.error != null &&
          next.error!.isNotEmpty &&
          next.error != prev?.error &&
          context.mounted) {
        showErrorDialog(context, next.error!);
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

    final busy = loading || _flowBusy;

    return Stack(
      children: [
        Scaffold(
          appBar: widget.hideAppBar
              ? null
              : AppBar(
                  title: Text(_sectionTitle),
                  leading: IconButton(
                    icon: const Icon(Icons.arrow_back),
                    onPressed: busy ? null : _prevPage,
                  ),
                  bottom: PreferredSize(
                    preferredSize: const Size.fromHeight(4),
                    child: LinearProgressIndicator(
                      value: (_pageIndex + 1) / _totalPages,
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
                    _sectionTitle,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ),
                LinearProgressIndicator(
                  value: (_pageIndex + 1) / _totalPages,
                  backgroundColor:
                      Theme.of(context).colorScheme.surfaceContainerHighest,
                ),
                const SizedBox(height: 8),
              ],
              Expanded(
                child: PageView(
                  controller: _pageController!,
                  onPageChanged: (i) => setState(() => _pageIndex = i),
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
                    if (_pageIndex > 0)
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
                              _pageIndex == _totalPages - 1
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
        if (_flowBusy) ...[
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
          value: _mealsPerDay,
          min: 2,
          max: 6,
          divisions: 4,
          valueLabel: (v) => '${v.round()}',
          onChanged: (v) => setState(() => _mealsPerDay = v),
        ),
        const SizedBox(height: 24),
        Text(
          '2. Per te è importante rispettare orari fissi dei pasti?',
          style: Theme.of(context).textTheme.bodyLarge,
        ),
        const SizedBox(height: 8),
        SwitchListTile(
          title: const Text('Timing dei pasti importante'),
          value: _timingImportante,
          onChanged: (v) => setState(() => _timingImportante = v),
        ),
        const SizedBox(height: 16),
        MultiSelectChipGroup(
          title: '3. Con che frequenza mangi fuori casa o ordini delivery?',
          options: _fuoriOptions,
          selected: _fuoriCasa,
          onChanged: (s) => setState(() => _fuoriCasa
            ..clear()
            ..addAll(s)),
        ),
      ],
    );
  }

  Widget _columnSection2() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        MultiSelectChipGroup(
          title: '4. Allergie o intolleranze da considerare',
          options: _allergieOptions,
          selected: _allergie,
          onChanged: (s) => setState(() => _allergie
            ..clear()
            ..addAll(s)),
        ),
        const SizedBox(height: 24),
        MultiSelectChipGroup(
          title: '5. Preferenze o alimenti da escludere',
          options: _esclusioniOptions,
          selected: _esclusioni,
          onChanged: (s) => setState(() => _esclusioni
            ..clear()
            ..addAll(s)),
        ),
      ],
    );
  }

  Widget _columnSection3(
    List<String> styleLabels,
    Map<String, String> keyForStyleLabel,
  ) {
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
              selected: _nutritionObjective == e.$1,
              onSelected: (_) => setState(() => _nutritionObjective = e.$1),
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
              selected: _speed == e.$1,
              onSelected: (_) => setState(() => _speed = e.$1),
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
              .firstWhere((e) => e.$1 == _styleKey, orElse: () => _stylePairs.first)
              .$2,
          hint: 'Cerca o scegli…',
          onChanged: (label) {
            if (label != null) {
              setState(() => _styleKey = keyForStyleLabel[label] ?? _styleKey);
            }
          },
        ),
      ],
    );
  }

  Widget _columnSection4() {
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
              selected: _proteinLevel == e.$1,
              onSelected: (_) => setState(() => _proteinLevel = e.$1),
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
              selected: _carbStyle == e.$1,
              onSelected: (_) => setState(() => _carbStyle = e.$1),
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
          value: _useSupplements,
          onChanged: (v) => setState(() => _useSupplements = v),
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
