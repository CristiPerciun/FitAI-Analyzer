import 'package:fitai_analyzer/providers/main_profile_form_provider.dart';
import 'package:fitai_analyzer/providers/user_profile_notifier.dart';
import 'package:fitai_analyzer/ui/widgets/multi_select_chip.dart';
import 'package:fitai_analyzer/utils/goal_options.dart';
import 'package:fitai_analyzer/utils/onboarding_questions.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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

/// Tutte le domande onboarding principale in un unico blocco (scroll gestito dal genitore).
/// Lo stato vive in [mainProfileFormProvider]; qui restano solo i
/// `TextEditingController` per il loro ciclo di vita. Usato da
/// [CombinedOnboardingEditScreen] da Impostazioni.
class MainProfileSinglePageFields extends ConsumerStatefulWidget {
  const MainProfileSinglePageFields({super.key});

  @override
  ConsumerState<MainProfileSinglePageFields> createState() =>
      _MainProfileSinglePageFieldsState();
}

class _MainProfileSinglePageFieldsState
    extends ConsumerState<MainProfileSinglePageFields> {
  final _ageController = TextEditingController();
  final _heightController = TextEditingController();
  final _weightController = TextEditingController();
  final _medicationsController = TextEditingController();
  final _healthConditionsController = TextEditingController();
  final _targetWeightController = TextEditingController();
  final _zone2Controller = TextEditingController();

  bool _seeded = false;

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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final notifier = ref.read(mainProfileFormProvider.notifier);
    final form = ref.watch(mainProfileFormProvider);
    final vis = visibilityForGoal(form.mainGoal);

    // Seed una sola volta dal profilo caricato (i controller dei testi vengono
    // inizializzati dallo stato risultante; mai assegnati in build successivi).
    final p = ref.watch(userProfileNotifierProvider).profile;
    if (p != null && !_seeded) {
      _seeded = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        notifier.seedFrom(p);
        final s = ref.read(mainProfileFormProvider);
        _ageController.text = s.ageText;
        _heightController.text = s.heightText;
        _weightController.text = s.weightText;
        _targetWeightController.text = s.targetWeightText;
        _zone2Controller.text = s.zone2Text;
        _medicationsController.text = s.medicationsText;
        _healthConditionsController.text = s.healthConditionsText;
      });
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Obiettivo principale',
          style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(
          'Scegli l\'obiettivo principale per personalizzare il tuo piano AI',
          style: theme.textTheme.bodyLarge?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
          // Evita ValueKey(null) durante il primo build (quando mainGoal è null)
          // che genera l'errore runtime: "Duplicate keys found".
          key: const ValueKey('mainGoalDropdown'),
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
        const SizedBox(height: 28),
        Text(
          'Informazioni base',
          style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 12),
        Text(
          'Inserisci le tue informazioni per un piano personalizzato',
          style: theme.textTheme.bodyLarge?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
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
          key: const ValueKey('genderDropdown'),
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
        const SizedBox(height: 28),
        Text(
          'Allenamento',
          style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 12),
        Text(
          'Quanto puoi allenarti e che attrezzatura hai a disposizione?',
          style: theme.textTheme.bodyLarge?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<int>(
          key: const ValueKey('trainingDaysDropdown'),
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
          key: const ValueKey('equipmentDropdown'),
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
          key: const ValueKey('dailyActivityDropdown'),
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
            key: const ValueKey('trainingExperienceDropdown'),
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
            key: const ValueKey('trainingFocusDropdown'),
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
        const SizedBox(height: 28),
        Text(
          'Salute e recupero',
          style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 12),
        Text(
          'Farmaci, condizioni di salute e qualità del sonno',
          style: theme.textTheme.bodyLarge?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
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
          style: theme.textTheme.titleSmall,
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
          style: theme.textTheme.titleSmall,
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
}
