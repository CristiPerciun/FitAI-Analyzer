import 'package:fitai_analyzer/providers/main_profile_form_provider.dart';
import 'package:fitai_analyzer/providers/user_profile_notifier.dart';
import 'package:fitai_analyzer/theme/app_theme.dart';
import 'package:fitai_analyzer/ui/onboarding/nutrition_goal_screen.dart';
import 'package:fitai_analyzer/ui/widgets/error_dialog.dart';
import 'package:fitai_analyzer/ui/widgets/multi_select_chip.dart';
import 'package:fitai_analyzer/utils/goal_options.dart';
import 'package:fitai_analyzer/utils/onboarding_questions.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

const _genderOptions = [
  ('male', 'Maschio'),
  ('female', 'Femmina'),
  ('other', 'Altro'),
];

const _trainingDaysOptions = [
  (3, '3'),
  (4, '4'),
  (5, '5'),
  (6, '6'),
  (7, '7+'),
];

const _equipmentOptions = [
  ('bodyweight', 'Solo corpo libero'),
  ('home_gym', 'Casa con manubri'),
  ('full_gym', 'Palestra completa'),
];

/// Pagina corrente del wizard onboarding (0–3). AutoDispose: si azzera all'uscita.
final onboardingPageIndexProvider = StateProvider.autoDispose<int>((ref) => 0);

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _formKey = GlobalKey<FormState>();

  // I valori vivono in [mainProfileFormProvider]; qui restano solo i controller.
  final _ageController = TextEditingController();
  final _heightController = TextEditingController();
  final _weightController = TextEditingController();
  final _medicationsController = TextEditingController();
  final _healthConditionsController = TextEditingController();
  final _targetWeightController = TextEditingController();
  final _zone2Controller = TextEditingController();

  // Non chiamare loadProfile in initState: _LoggedInGate l'ha già fatto.

  @override
  void dispose() {
    _ageController.dispose();
    _heightController.dispose();
    _weightController.dispose();
    _medicationsController.dispose();
    _healthConditionsController.dispose();
    _targetWeightController.dispose();
    _zone2Controller.dispose();
    super.dispose();
  }

  String? _validateAge(String? v) {
    if (v == null || v.trim().isEmpty) return 'Inserisci l\'età';
    final n = int.tryParse(v.trim());
    if (n == null || n < 10 || n > 120) return 'Età tra 10 e 120';
    return null;
  }

  String? _validateHeight(String? v) {
    if (v == null || v.trim().isEmpty) return 'Inserisci l\'altezza';
    final n = double.tryParse(v.trim());
    if (n == null || n < 50 || n > 250) return 'Altezza tra 50 e 250 cm';
    return null;
  }

  String? _validateWeight(String? v) {
    if (v == null || v.trim().isEmpty) return 'Inserisci il peso';
    final n = double.tryParse(v.trim());
    if (n == null || n < 20 || n > 300) return 'Peso tra 20 e 300 kg';
    return null;
  }

  void _onContinue() {
    final form = ref.read(mainProfileFormProvider);
    final pageIndex = ref.read(onboardingPageIndexProvider);
    final pageNotifier = ref.read(onboardingPageIndexProvider.notifier);
    if (pageIndex == 0) {
      if (form.mainGoal == null) return;
      pageNotifier.state = 1;
      return;
    }
    if (pageIndex == 1) {
      if (!_formKey.currentState!.validate()) return;
      if (form.gender == null) {
        showErrorDialog(context, 'Seleziona il sesso biologico');
        return;
      }
      pageNotifier.state = 2;
      return;
    }
    if (pageIndex == 2) {
      if (form.trainingDaysPerWeek == null) {
        showErrorDialog(context, 'Seleziona i giorni di allenamento');
        return;
      }
      if (form.equipment == null) {
        showErrorDialog(context, 'Seleziona l\'attrezzatura');
        return;
      }
      pageNotifier.state = 3;
      return;
    }
    _saveAndNavigate();
  }

  void _onSkip() {
    final pageIndex = ref.read(onboardingPageIndexProvider);
    if (pageIndex < 3) {
      ref.read(onboardingPageIndexProvider.notifier).state = pageIndex + 1;
    } else {
      _saveAndNavigate();
    }
  }

  Future<void> _saveAndNavigate() async {
    final profile = ref.read(mainProfileFormProvider.notifier).buildMergedProfile();
    try {
      await ref.read(userProfileNotifierProvider.notifier).saveProfile(profile);
      if (!mounted) return;
      await Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (_) => const NutritionGoalScreen(),
        ),
      );
      if (mounted) context.go('/');
    } catch (e) {
      if (mounted) showErrorDialog(context, e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final profileState = ref.watch(userProfileNotifierProvider);
    final pageIndex = ref.watch(onboardingPageIndexProvider);

    ref.listen(userProfileNotifierProvider, (prev, next) {
      if (next.error != null &&
          next.error!.isNotEmpty &&
          next.error != prev?.error &&
          context.mounted) {
        showErrorDialog(context, next.error!);
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: Text(_pageTitleFor(pageIndex)),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(4),
          child: LinearProgressIndicator(
            value: (pageIndex + 1) / 4,
            backgroundColor:
                Theme.of(context).colorScheme.surfaceContainerHighest,
          ),
        ),
      ),
      body: Form(
        key: _formKey,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final maxWidth =
                  constraints.maxWidth > 600 ? 400.0 : constraints.maxWidth;
              return SingleChildScrollView(
                child: Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: maxWidth),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildPageContent(pageIndex),
                        const SizedBox(height: 32),
                        _buildActions(profileState.isLoading, pageIndex),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  String _pageTitleFor(int pageIndex) {
    switch (pageIndex) {
      case 0:
        return 'Obiettivo principale';
      case 1:
        return 'Informazioni base';
      case 2:
        return 'Allenamento';
      case 3:
        return 'Salute e recupero';
      default:
        return 'Onboarding';
    }
  }

  Widget _buildPageContent(int pageIndex) {
    switch (pageIndex) {
      case 0:
        return _buildPage1();
      case 1:
        return _buildPage2();
      case 2:
        return _buildPage3();
      case 3:
        return _buildPage4();
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildPage1() {
    final form = ref.watch(mainProfileFormProvider);
    final notifier = ref.read(mainProfileFormProvider.notifier);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Scegli l\'obiettivo principale per personalizzare il tuo piano AI',
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.8),
              ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        DropdownButtonFormField<String>(
          key: ValueKey(form.mainGoal),
          initialValue: form.mainGoal,
          decoration: const InputDecoration(
            labelText: 'Obiettivo principale',
            border: OutlineInputBorder(),
          ),
          items: mainGoalOptions
              .map((e) => DropdownMenuItem(value: e.$1, child: Text(e.$2)))
              .toList(),
          onChanged: notifier.setMainGoal,
        ),
      ],
    );
  }

  Widget _buildPage2() {
    final form = ref.watch(mainProfileFormProvider);
    final notifier = ref.read(mainProfileFormProvider.notifier);
    final vis = visibilityForGoal(form.mainGoal);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Inserisci le tue informazioni per un piano personalizzato',
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.8),
              ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        TextFormField(
          controller: _ageController,
          decoration: const InputDecoration(
            labelText: 'Età',
            hintText: 'Es. 28',
            border: OutlineInputBorder(),
          ),
          keyboardType: TextInputType.number,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(3),
          ],
          validator: _validateAge,
          onChanged: notifier.setAgeText,
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
          key: ValueKey(form.gender),
          initialValue: form.gender,
          decoration: const InputDecoration(
            labelText: 'Sesso biologico',
            border: OutlineInputBorder(),
          ),
          items: _genderOptions
              .map((e) => DropdownMenuItem(value: e.$1, child: Text(e.$2)))
              .toList(),
          onChanged: notifier.setGender,
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _heightController,
          decoration: const InputDecoration(
            labelText: 'Altezza (cm)',
            hintText: 'Es. 175',
            border: OutlineInputBorder(),
          ),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
            LengthLimitingTextInputFormatter(5),
          ],
          validator: _validateHeight,
          onChanged: notifier.setHeightText,
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _weightController,
          decoration: const InputDecoration(
            labelText: 'Peso attuale (kg)',
            hintText: 'Es. 72',
            border: OutlineInputBorder(),
          ),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
            LengthLimitingTextInputFormatter(5),
          ],
          validator: _validateWeight,
          onChanged: notifier.setWeightText,
        ),
        if (vis.showTargetWeight) ...[
          const SizedBox(height: 16),
          TextFormField(
            controller: _targetWeightController,
            decoration: const InputDecoration(
              labelText: 'Peso obiettivo (kg)',
              hintText: 'Es. 68',
              border: OutlineInputBorder(),
            ),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
              LengthLimitingTextInputFormatter(5),
            ],
            onChanged: notifier.setTargetWeightText,
          ),
        ],
      ],
    );
  }

  Widget _buildPage3() {
    final form = ref.watch(mainProfileFormProvider);
    final notifier = ref.read(mainProfileFormProvider.notifier);
    final vis = visibilityForGoal(form.mainGoal);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Quanto puoi allenarti e che attrezzatura hai a disposizione?',
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.8),
              ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        DropdownButtonFormField<int>(
          key: ValueKey(form.trainingDaysPerWeek),
          initialValue: form.trainingDaysPerWeek,
          decoration: const InputDecoration(
            labelText: 'Giorni di allenamento a settimana',
            border: OutlineInputBorder(),
          ),
          items: _trainingDaysOptions
              .map((e) => DropdownMenuItem(value: e.$1, child: Text(e.$2)))
              .toList(),
          onChanged: notifier.setTrainingDays,
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
          key: ValueKey(form.equipment),
          initialValue: form.equipment,
          decoration: const InputDecoration(
            labelText: 'Attrezzatura disponibile',
            border: OutlineInputBorder(),
          ),
          items: _equipmentOptions
              .map((e) => DropdownMenuItem(value: e.$1, child: Text(e.$2)))
              .toList(),
          onChanged: notifier.setEquipment,
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
          key: ValueKey('dailyActivity_${form.dailyActivityLevel}'),
          initialValue: form.dailyActivityLevel,
          isExpanded: true,
          decoration: const InputDecoration(
            labelText: 'Attività quotidiana (fuori allenamento)',
            border: OutlineInputBorder(),
          ),
          items: dailyActivityOptions
              .map((e) => DropdownMenuItem(value: e.$1, child: Text(e.$2)))
              .toList(),
          onChanged: notifier.setDailyActivity,
        ),
        if (vis.showTrainingExperience) ...[
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            key: ValueKey('trainingExperience_${form.trainingExperience}'),
            initialValue: form.trainingExperience,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Esperienza di allenamento',
              border: OutlineInputBorder(),
            ),
            items: trainingExperienceOptions
                .map((e) => DropdownMenuItem(value: e.$1, child: Text(e.$2)))
                .toList(),
            onChanged: notifier.setTrainingExperience,
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            key: ValueKey('trainingFocus_${form.trainingFocus}'),
            initialValue: form.trainingFocus,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Focus allenamento',
              border: OutlineInputBorder(),
            ),
            items: trainingFocusOptions
                .map((e) => DropdownMenuItem(value: e.$1, child: Text(e.$2)))
                .toList(),
            onChanged: notifier.setTrainingFocus,
          ),
        ],
        if (vis.showLongevityPriorities) ...[
          const SizedBox(height: 24),
          MultiSelectChipGroup(
            title: 'Priorità di longevità (puoi sceglierne più di una)',
            options: longevityPriorityOptions
                .map((e) => MultiSelectOption(id: e.$1, label: e.$2))
                .toList(),
            selected: form.longevityPriorities,
            onChanged: notifier.setLongevityPriorities,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _zone2Controller,
            decoration: const InputDecoration(
              labelText: 'Target Zone 2 (minuti / settimana)',
              hintText: 'Es. 150',
              border: OutlineInputBorder(),
            ),
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(3),
            ],
            onChanged: notifier.setZone2Text,
          ),
        ],
      ],
    );
  }

  Widget _buildPage4() {
    final form = ref.watch(mainProfileFormProvider);
    final notifier = ref.read(mainProfileFormProvider.notifier);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Farmaci, condizioni di salute e qualità del sonno',
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.8),
              ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        SwitchListTile(
          title: const Text('Assumi farmaci regolarmente'),
          value: form.takesMedications,
          onChanged: notifier.setTakesMedications,
        ),
        if (form.takesMedications) ...[
          const SizedBox(height: 8),
          TextFormField(
            controller: _medicationsController,
            decoration: const InputDecoration(
              labelText: 'Elenco farmaci (opzionale)',
              hintText: 'Es. metformina, statine...',
              border: OutlineInputBorder(),
              alignLabelWithHint: true,
            ),
            maxLines: 2,
            onChanged: notifier.setMedicationsText,
          ),
        ],
        const SizedBox(height: 16),
        TextFormField(
          controller: _healthConditionsController,
          decoration: const InputDecoration(
            labelText: 'Condizioni di salute (opzionale)',
            hintText: 'Es. diabete, ipertensione...',
            border: OutlineInputBorder(),
            alignLabelWithHint: true,
          ),
          maxLines: 2,
          onChanged: notifier.setHealthConditionsText,
        ),
        const SizedBox(height: 24),
        Text(
          'Ore di sonno medie: ${form.avgSleepHours.toStringAsFixed(1)}',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        Slider(
          value: form.avgSleepHours,
          min: 4,
          max: 12,
          divisions: 16,
          label: form.avgSleepHours.toStringAsFixed(1),
          onChanged: notifier.setAvgSleepHours,
        ),
        const SizedBox(height: 16),
        Text(
          'Importanza recupero (1-5): ${form.sleepImportance}',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        Slider(
          value: form.sleepImportance.toDouble(),
          min: 1,
          max: 5,
          divisions: 4,
          label: '${form.sleepImportance}',
          onChanged: (v) => notifier.setSleepImportance(v.round()),
        ),
      ],
    );
  }

  Widget _buildActions(bool isLoading, int pageIndex) {
    final isLastPage = pageIndex == 3;
    return Row(
      children: [
        if (!isLastPage)
          TextButton(
            onPressed: isLoading ? null : _onSkip,
            child: const Text('Salta'),
          ),
        const Spacer(),
        FilledButton(
          onPressed: isLoading ? null : _onContinue,
          child: isLoading
              ? const SizedBox(
                  height: 24,
                  width: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.white,
                  ),
                )
              : Text(isLastPage ? 'Genera piano AI' : 'Continua'),
        ),
      ],
    );
  }
}
