import 'package:fitai_analyzer/models/user_profile.dart';
import 'package:fitai_analyzer/providers/user_profile_notifier.dart';
import 'package:fitai_analyzer/ui/theme/app_colors.dart';
import 'package:fitai_analyzer/ui/widgets/error_dialog.dart';
import 'package:fitai_analyzer/utils/goal_options.dart';
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

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _formKey = GlobalKey<FormState>();
  int _pageIndex = 0;

  // Page 1
  String? _mainGoal;

  // Page 2
  final _ageController = TextEditingController();
  String? _gender;
  final _heightController = TextEditingController();
  final _weightController = TextEditingController();

  // Page 3
  int? _trainingDaysPerWeek;
  String? _equipment;

  // Page 4
  bool _takesMedications = false;
  final _medicationsController = TextEditingController();
  final _healthConditionsController = TextEditingController();
  double _avgSleepHours = 7.0;
  int _sleepImportance = 3;

  // Non chiamare loadProfile in initState: _LoggedInGate l'ha già fatto.
  // Richiamarlo metterebbe isLoading=true e causerebbe flickering.

  @override
  void dispose() {
    _ageController.dispose();
    _heightController.dispose();
    _weightController.dispose();
    _medicationsController.dispose();
    _healthConditionsController.dispose();
    super.dispose();
  }

  double get _progress => (_pageIndex + 1) / 4;

  UserProfile _buildProfileWithDefaults() {
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
    if (_pageIndex == 0) {
      if (_mainGoal == null) return;
      setState(() => _pageIndex = 1);
      return;
    }
    if (_pageIndex == 1) {
      if (!_formKey.currentState!.validate()) return;
      if (_gender == null) {
        showErrorDialog(context, 'Seleziona il sesso biologico');
        return;
      }
      setState(() => _pageIndex = 2);
      return;
    }
    if (_pageIndex == 2) {
      if (_trainingDaysPerWeek == null) {
        showErrorDialog(context, 'Seleziona i giorni di allenamento');
        return;
      }
      if (_equipment == null) {
        showErrorDialog(context, 'Seleziona l\'attrezzatura');
        return;
      }
      setState(() => _pageIndex = 3);
      return;
    }
    _saveAndNavigate();
  }

  void _onSkip() {
    if (_pageIndex < 3) {
      setState(() => _pageIndex++);
    } else {
      _saveAndNavigate();
    }
  }

  Future<void> _saveAndNavigate() async {
    final profile = _buildProfileWithDefaults();
    try {
      await ref.read(userProfileNotifierProvider.notifier).saveProfile(profile);
      if (mounted) context.go('/');
    } catch (e) {
      if (mounted) showErrorDialog(context, e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final profileState = ref.watch(userProfileNotifierProvider);

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
        title: Text(_pageTitle),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(4),
          child: LinearProgressIndicator(
            value: _progress,
            backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
          ),
        ),
      ),
      body: Form(
        key: _formKey,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final maxWidth = constraints.maxWidth > 600 ? 400.0 : constraints.maxWidth;
              return SingleChildScrollView(
                child: Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: maxWidth),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildPageContent(),
                        const SizedBox(height: 32),
                        _buildActions(profileState.isLoading),
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

  String get _pageTitle {
    switch (_pageIndex) {
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

  Widget _buildPageContent() {
    switch (_pageIndex) {
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
      ],
    );
  }

  Widget _buildPage2() {
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
      ],
    );
  }

  Widget _buildPage3() {
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
      ],
    );
  }

  Widget _buildPage4() {
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
          style: Theme.of(context).textTheme.titleSmall,
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
          style: Theme.of(context).textTheme.titleSmall,
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

  Widget _buildActions(bool isLoading) {
    final isLastPage = _pageIndex == 3;
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
