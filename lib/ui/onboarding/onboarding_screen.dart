import 'package:fitai_analyzer/models/user_profile.dart';
import 'package:fitai_analyzer/providers/user_profile_notifier.dart';
import 'package:fitai_analyzer/ui/theme/app_colors.dart';
import 'package:fitai_analyzer/ui/widgets/error_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

const _mainGoalOptions = [
  ('weight_loss', 'Perdita di peso / riduzione grasso'),
  ('muscle_gain', 'Guadagno massa muscolare / ipertrofia'),
  ('longevity', 'Longevità / salute a lungo termine'),
  ('strength', 'Migliorare forza generale'),
  ('other', 'Altro'),
];

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _formKey = GlobalKey<FormState>();
  String? _selectedGoal;
  String _otherGoalText = '';
  bool _hasValidationError = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(userProfileNotifierProvider.notifier).loadProfile();
    });
  }

  Future<void> _onContinue() async {
    if (_selectedGoal == null) {
      setState(() => _hasValidationError = true);
      return;
    }
    setState(() => _hasValidationError = false);

    final profile = ref.read(userProfileNotifierProvider).profile ??
        const UserProfile();
    final goalSpecificTarget = _selectedGoal == 'other'
        ? (_otherGoalText.isEmpty ? null : _otherGoalText)
        : profile.goalSpecificTarget;

    final updatedProfile = UserProfile(
      mainGoal: _selectedGoal,
      experienceLevel: profile.experienceLevel,
      age: profile.age,
      gender: profile.gender,
      heightCm: profile.heightCm,
      weightKg: profile.weightKg,
      injuriesOrConditions: profile.injuriesOrConditions,
      trainingDaysPerWeek: profile.trainingDaysPerWeek,
      equipment: profile.equipment,
      preferredSessionDuration: profile.preferredSessionDuration,
      dietPreference: profile.dietPreference,
      goalSpecificTarget: goalSpecificTarget,
    );

    try {
      await ref.read(userProfileNotifierProvider.notifier).saveProfile(updatedProfile);
      if (mounted) context.go('/onboarding/details');
    } catch (e) {
      if (mounted) showErrorDialog(context, e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final profileState = ref.watch(userProfileNotifierProvider);
    final isOtherSelected = _selectedGoal == 'other';

    ref.listen(userProfileNotifierProvider, (prev, next) {
      if (_selectedGoal == null &&
          next.profile != null &&
          prev?.profile != next.profile &&
          mounted) {
        setState(() {
          _selectedGoal = next.profile!.mainGoal;
          _otherGoalText = next.profile!.mainGoal == 'other'
              ? (next.profile!.goalSpecificTarget ?? '')
              : '';
        });
      }
    });

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
        title: const Text('Il tuo obiettivo principale'),
      ),
      body: Form(
        key: _formKey,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final cardWidth = constraints.maxWidth > 600
                  ? constraints.maxWidth * 0.5
                  : constraints.maxWidth;
              return SingleChildScrollView(
                child: Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: cardWidth),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Scegli l\'obiettivo principale per personalizzare il tuo piano AI',
                          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurface
                                    .withValues(alpha: 0.8),
                              ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 32),
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                DropdownButtonFormField<String>(
                                  initialValue: _selectedGoal,
                                  decoration: InputDecoration(
                                    labelText: 'Obiettivo principale',
                                    errorText: _hasValidationError
                                        ? 'Seleziona un obiettivo'
                                        : null,
                                    border: const OutlineInputBorder(),
                                  ),
                                  hint: const Text('Seleziona un obiettivo'),
                                  items: _mainGoalOptions
                                      .map(
                                        (e) => DropdownMenuItem(
                                          value: e.$1,
                                          child: Text(e.$2),
                                        ),
                                      )
                                      .toList(),
                                  onChanged: (value) {
                                    setState(() {
                                      _selectedGoal = value;
                                      _hasValidationError = false;
                                    });
                                  },
                                ),
                                if (isOtherSelected) ...[
                                  const SizedBox(height: 20),
                                  TextFormField(
                                    initialValue: _otherGoalText,
                                    decoration: const InputDecoration(
                                      labelText: 'Descrivi il tuo obiettivo',
                                      hintText: 'Es. migliorare resistenza',
                                      border: OutlineInputBorder(),
                                    ),
                                    maxLines: 2,
                                    onChanged: (v) =>
                                        setState(() => _otherGoalText = v),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 32),
                        FilledButton(
                          onPressed: profileState.isLoading ? null : _onContinue,
                          child: profileState.isLoading
                              ? const SizedBox(
                                  height: 24,
                                  width: 24,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: AppColors.white,
                                  ),
                                )
                              : const Text('Continua'),
                        ),
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
}
