import 'package:fitai_analyzer/models/user_profile.dart';
import 'package:fitai_analyzer/providers/user_profile_notifier.dart';
import 'package:fitai_analyzer/ui/widgets/error_dialog.dart';
import 'package:fitai_analyzer/utils/goal_options.dart';
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
/// Usato da [CombinedOnboardingEditScreen] da Impostazioni.
class MainProfileSinglePageFields extends ConsumerStatefulWidget {
  const MainProfileSinglePageFields({super.key});

  @override
  ConsumerState<MainProfileSinglePageFields> createState() =>
      MainProfileSinglePageFieldsState();
}

class MainProfileSinglePageFieldsState
    extends ConsumerState<MainProfileSinglePageFields> {
  String? _mainGoal;
  final _ageController = TextEditingController();
  String? _gender;
  final _heightController = TextEditingController();
  final _weightController = TextEditingController();
  int? _trainingDaysPerWeek;
  String? _equipment;
  bool _takesMedications = false;
  final _medicationsController = TextEditingController();
  final _healthConditionsController = TextEditingController();
  double _avgSleepHours = 7.0;
  int _sleepImportance = 3;
  bool _seeded = false;

  @override
  void dispose() {
    _ageController.dispose();
    _heightController.dispose();
    _weightController.dispose();
    _medicationsController.dispose();
    _healthConditionsController.dispose();
    super.dispose();
  }

  void seedFrom(UserProfile p) {
    if (_seeded) return;
    _seeded = true;
    setState(() {
      _mainGoal = p.mainGoal;
      _ageController.text = p.age.toString();
      _gender = p.gender;
      _heightController.text = p.heightCm.toString();
      _weightController.text = p.weightKg.toString();
      _trainingDaysPerWeek = p.trainingDaysPerWeek;
      _equipment = p.equipment;
      _takesMedications = p.takesMedications;
      _medicationsController.text = p.medicationsList;
      _healthConditionsController.text = p.healthConditions;
      _avgSleepHours = p.avgSleepHours;
      _sleepImportance = p.sleepImportance.clamp(1, 5);
    });
  }

  UserProfile _buildBase() {
    return UserProfile(
      mainGoal: _mainGoal ?? 'longevity',
      age: int.tryParse(_ageController.text.trim()) ?? 30,
      gender: _gender ?? 'male',
      heightCm: double.tryParse(_heightController.text.trim()) ?? 170,
      weightKg: double.tryParse(_weightController.text.trim()) ?? 70,
      trainingDaysPerWeek: _trainingDaysPerWeek ?? 4,
      equipment: _equipment ?? 'full_gym',
      takesMedications: _takesMedications,
      medicationsList: _medicationsController.text.trim(),
      healthConditions: _healthConditionsController.text.trim(),
      avgSleepHours: _avgSleepHours,
      sleepImportance: _sleepImportance,
    );
  }

  /// Profilo principale + conserva ramo nutrizione e training dal profilo corrente in Firestore.
  UserProfile buildMergedProfile() {
    final b = _buildBase();
    final cur = ref.read(userProfileNotifierProvider).profile;
    return UserProfile(
      mainGoal: b.mainGoal,
      age: b.age,
      gender: b.gender,
      heightCm: b.heightCm,
      weightKg: b.weightKg,
      trainingDaysPerWeek: b.trainingDaysPerWeek,
      equipment: b.equipment,
      takesMedications: b.takesMedications,
      medicationsList: b.medicationsList,
      healthConditions: b.healthConditions,
      avgSleepHours: b.avgSleepHours,
      sleepImportance: b.sleepImportance,
      nutritionGoal: cur?.nutritionGoal,
      trainingGoal: cur?.trainingGoal,
    );
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

  /// Valida i campi (richiede [Form] antenato per i TextFormField).
  bool validateAll() {
    if (_mainGoal == null) {
      showErrorDialog(context, 'Seleziona l\'obiettivo principale');
      return false;
    }
    final form = Form.maybeOf(context);
    if (form != null && !form.validate()) return false;
    if (_gender == null) {
      showErrorDialog(context, 'Seleziona il sesso biologico');
      return false;
    }
    if (_trainingDaysPerWeek == null) {
      showErrorDialog(context, 'Seleziona i giorni di allenamento');
      return false;
    }
    if (_equipment == null) {
      showErrorDialog(context, 'Seleziona l\'attrezzatura');
      return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final p = ref.watch(userProfileNotifierProvider).profile;
    if (p != null && !_seeded) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) seedFrom(p);
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
          key: ValueKey(_mainGoal),
          initialValue: _mainGoal,
          decoration: const InputDecoration(
            labelText: 'Obiettivo principale',
            border: OutlineInputBorder(),
          ),
          items: mainGoalOptions
              .map((e) => DropdownMenuItem(value: e.$1, child: Text(e.$2)))
              .toList(),
          onChanged: (v) => setState(() => _mainGoal = v),
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
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
          key: ValueKey(_gender),
          initialValue: _gender,
          decoration: const InputDecoration(
            labelText: 'Sesso biologico',
            border: OutlineInputBorder(),
          ),
          items: _genderOptions
              .map((e) => DropdownMenuItem(value: e.$1, child: Text(e.$2)))
              .toList(),
          onChanged: (v) => setState(() => _gender = v),
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
        ),
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
          key: ValueKey(_trainingDaysPerWeek),
          initialValue: _trainingDaysPerWeek,
          decoration: const InputDecoration(
            labelText: 'Giorni di allenamento a settimana',
            border: OutlineInputBorder(),
          ),
          items: _trainingDaysOptions
              .map((e) => DropdownMenuItem(value: e.$1, child: Text(e.$2)))
              .toList(),
          onChanged: (v) => setState(() => _trainingDaysPerWeek = v),
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
          key: ValueKey(_equipment),
          initialValue: _equipment,
          decoration: const InputDecoration(
            labelText: 'Attrezzatura disponibile',
            border: OutlineInputBorder(),
          ),
          items: _equipmentOptions
              .map((e) => DropdownMenuItem(value: e.$1, child: Text(e.$2)))
              .toList(),
          onChanged: (v) => setState(() => _equipment = v),
        ),
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
          value: _takesMedications,
          onChanged: (v) => setState(() => _takesMedications = v),
        ),
        if (_takesMedications) ...[
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
        ),
        const SizedBox(height: 24),
        Text(
          'Ore di sonno medie: ${_avgSleepHours.toStringAsFixed(1)}',
          style: theme.textTheme.titleSmall,
        ),
        Slider(
          value: _avgSleepHours,
          min: 4,
          max: 12,
          divisions: 16,
          label: _avgSleepHours.toStringAsFixed(1),
          onChanged: (v) => setState(() => _avgSleepHours = v),
        ),
        const SizedBox(height: 16),
        Text(
          'Importanza recupero (1-5): $_sleepImportance',
          style: theme.textTheme.titleSmall,
        ),
        Slider(
          value: _sleepImportance.toDouble(),
          min: 1,
          max: 5,
          divisions: 4,
          label: '$_sleepImportance',
          onChanged: (v) => setState(() => _sleepImportance = v.round()),
        ),
      ],
    );
  }
}
