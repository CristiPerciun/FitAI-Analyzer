import 'package:fitai_analyzer/models/user_profile.dart';
import 'package:fitai_analyzer/providers/user_profile_notifier.dart';
import 'package:fitai_analyzer/ui/theme/app_colors.dart';
import 'package:fitai_analyzer/ui/widgets/error_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

const _experienceOptions = [
  (1, 'Principiante'),
  (2, 'Intermedio'),
  (3, 'Avanzato'),
];

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

const _sessionDurationOptions = [
  ('short', '20-30 min'),
  ('medium', '45 min'),
  ('long', '60+ min'),
];

const _dietOptions = [
  ('none', 'Nessuna restrizione'),
  ('omnivore', 'Omnivore'),
  ('vegetarian', 'Vegetariano'),
  ('vegan', 'Vegano'),
  ('low_carb', 'Low-carb'),
];

class OnboardingDetailsScreen extends ConsumerStatefulWidget {
  const OnboardingDetailsScreen({super.key});

  @override
  ConsumerState<OnboardingDetailsScreen> createState() =>
      _OnboardingDetailsScreenState();
}

class _OnboardingDetailsScreenState
    extends ConsumerState<OnboardingDetailsScreen> {
  final _formKey = GlobalKey<FormState>();
  int? _experienceLevel;
  final _ageController = TextEditingController();
  String? _gender;
  final _heightController = TextEditingController();
  final _weightController = TextEditingController();
  final _injuriesController = TextEditingController();
  int? _trainingDaysPerWeek;
  String? _equipment;
  String? _preferredSessionDuration;
  String? _dietPreference;

  @override
  void initState() {
    super.initState();
    Future.microtask(() => _loadExistingProfile());
  }

  Future<void> _loadExistingProfile() async {
    await ref.read(userProfileNotifierProvider.notifier).loadProfile();
    final profile = ref.read(userProfileNotifierProvider).profile;
    if (profile != null && mounted) {
      setState(() {
        _experienceLevel = profile.experienceLevel;
        _ageController.text = profile.age?.toString() ?? '';
        _gender = profile.gender;
        _heightController.text = profile.heightCm?.toString() ?? '';
        _weightController.text = profile.weightKg?.toString() ?? '';
        _injuriesController.text = profile.injuriesOrConditions ?? '';
        _trainingDaysPerWeek = profile.trainingDaysPerWeek;
        _equipment = profile.equipment;
        _preferredSessionDuration = profile.preferredSessionDuration;
        _dietPreference = profile.dietPreference ?? 'none';
      });
    }
  }

  @override
  void dispose() {
    _ageController.dispose();
    _heightController.dispose();
    _weightController.dispose();
    _injuriesController.dispose();
    super.dispose();
  }

  String? _validateRequiredNum(String? value, String fieldName) {
    if (value == null || value.trim().isEmpty) {
      return 'Inserisci $fieldName';
    }
    final n = num.tryParse(value.trim());
    if (n == null) return 'Valore non valido';
    if (n <= 0) return 'Deve essere maggiore di 0';
    return null;
  }

  String? _validateAge(String? value) {
    final err = _validateRequiredNum(value, 'l\'età');
    if (err != null) return err;
    final age = int.tryParse(value!.trim());
    if (age != null && (age < 10 || age > 120)) {
      return 'Età tra 10 e 120';
    }
    return null;
  }

  String? _validateHeight(String? value) {
    final err = _validateRequiredNum(value, 'l\'altezza');
    if (err != null) return err;
    final h = double.tryParse(value!.trim());
    if (h != null && (h < 50 || h > 250)) {
      return 'Altezza tra 50 e 250 cm';
    }
    return null;
  }

  String? _validateWeight(String? value) {
    final err = _validateRequiredNum(value, 'il peso');
    if (err != null) return err;
    final w = double.tryParse(value!.trim());
    if (w != null && (w < 20 || w > 300)) {
      return 'Peso tra 20 e 300 kg';
    }
    return null;
  }

  Future<void> _onGeneratePlan() async {
    if (!_formKey.currentState!.validate()) return;

    if (_experienceLevel == null) {
      if (mounted) showErrorDialog(context, 'Seleziona il livello di esperienza');
      return;
    }
    if (_gender == null) {
      if (mounted) showErrorDialog(context, 'Seleziona il sesso biologico');
      return;
    }
    if (_trainingDaysPerWeek == null) {
      if (mounted) showErrorDialog(context, 'Seleziona quanti giorni a settimana puoi allenarti');
      return;
    }
    if (_equipment == null) {
      if (mounted) showErrorDialog(context, 'Seleziona l\'attrezzatura disponibile');
      return;
    }
    if (_preferredSessionDuration == null) {
      if (mounted) showErrorDialog(context, 'Seleziona la durata sessione preferita');
      return;
    }

    final profile = ref.read(userProfileNotifierProvider).profile ??
        const UserProfile();
    final updatedProfile = UserProfile(
      mainGoal: profile.mainGoal,
      experienceLevel: _experienceLevel,
      age: int.tryParse(_ageController.text.trim()),
      gender: _gender,
      heightCm: double.tryParse(_heightController.text.trim()),
      weightKg: double.tryParse(_weightController.text.trim()),
      injuriesOrConditions: _injuriesController.text.trim().isEmpty
          ? null
          : _injuriesController.text.trim(),
      trainingDaysPerWeek: _trainingDaysPerWeek,
      equipment: _equipment,
      preferredSessionDuration: _preferredSessionDuration,
      dietPreference: _dietPreference == 'none' ? null : _dietPreference,
      goalSpecificTarget: profile.goalSpecificTarget,
    );

    try {
      await ref
          .read(userProfileNotifierProvider.notifier)
          .saveProfile(updatedProfile);
      if (mounted) context.go('/dashboard');
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
        title: const Text('Dettagli profilo'),
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Rispondi alle domande per personalizzare il tuo piano AI',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.8),
                    ),
              ),
              const SizedBox(height: 24),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Informazioni base',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<int>(
                        initialValue: _experienceLevel,
                        decoration: const InputDecoration(
                          labelText: 'Livello di esperienza',
                          border: OutlineInputBorder(),
                        ),
                        items: _experienceOptions
                            .map((e) => DropdownMenuItem(
                                  value: e.$1,
                                  child: Text(e.$2),
                                ))
                            .toList(),
                        onChanged: (v) => setState(() => _experienceLevel = v),
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
                        initialValue: _gender,
                        decoration: const InputDecoration(
                          labelText: 'Sesso biologico',
                          border: OutlineInputBorder(),
                        ),
                        items: _genderOptions
                            .map((e) => DropdownMenuItem(
                                  value: e.$1,
                                  child: Text(e.$2),
                                ))
                            .toList(),
                        onChanged: (v) => setState(() => _gender = v),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Corpo e limitazioni',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _heightController,
                        decoration: const InputDecoration(
                          labelText: 'Altezza (cm)',
                          hintText: 'Es. 175',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType:
                            const TextInputType.numberWithOptions(decimal: true),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                              RegExp(r'^\d*\.?\d{0,2}')),
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
                        keyboardType:
                            const TextInputType.numberWithOptions(decimal: true),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                              RegExp(r'^\d*\.?\d{0,2}')),
                          LengthLimitingTextInputFormatter(5),
                        ],
                        validator: _validateWeight,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _injuriesController,
                        decoration: const InputDecoration(
                          labelText:
                              'Limitazioni / infortuni (opzionale)',
                          hintText:
                              'Es. ginocchio destro, lombalgia cronica...',
                          border: OutlineInputBorder(),
                          alignLabelWithHint: true,
                        ),
                        maxLines: 3,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Allenamento',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<int>(
                        initialValue: _trainingDaysPerWeek,
                        decoration: const InputDecoration(
                          labelText:
                              'Quante volte a settimana puoi allenarti?',
                          border: OutlineInputBorder(),
                        ),
                        items: _trainingDaysOptions
                            .map((e) => DropdownMenuItem(
                                  value: e.$1,
                                  child: Text(e.$2),
                                ))
                            .toList(),
                        onChanged: (v) =>
                            setState(() => _trainingDaysPerWeek = v),
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        initialValue: _equipment,
                        decoration: const InputDecoration(
                          labelText: 'Attrezzatura disponibile',
                          border: OutlineInputBorder(),
                        ),
                        items: _equipmentOptions
                            .map((e) => DropdownMenuItem(
                                  value: e.$1,
                                  child: Text(e.$2),
                                ))
                            .toList(),
                        onChanged: (v) => setState(() => _equipment = v),
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        initialValue: _preferredSessionDuration,
                        decoration: const InputDecoration(
                          labelText: 'Durata sessione preferita',
                          border: OutlineInputBorder(),
                        ),
                        items: _sessionDurationOptions
                            .map((e) => DropdownMenuItem(
                                  value: e.$1,
                                  child: Text(e.$2),
                                ))
                            .toList(),
                        onChanged: (v) =>
                            setState(() => _preferredSessionDuration = v),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Alimentazione',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        initialValue: _dietPreference ?? 'none',
                        decoration: const InputDecoration(
                          labelText: 'Preferenze alimentari',
                          border: OutlineInputBorder(),
                        ),
                        items: _dietOptions
                            .map((e) => DropdownMenuItem<String>(
                                  value: e.$1,
                                  child: Text(e.$2),
                                ))
                            .toList(),
                        onChanged: (v) => setState(() => _dietPreference = v),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 32),
              FilledButton(
                onPressed: profileState.isLoading ? null : _onGeneratePlan,
                child: profileState.isLoading
                    ? const SizedBox(
                        height: 24,
                        width: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.white,
                        ),
                      )
                    : const Text('Genera il mio piano AI'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
