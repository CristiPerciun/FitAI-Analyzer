import 'dart:typed_data';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:fitai_analyzer/models/meal_model.dart';
import 'package:fitai_analyzer/models/user_profile.dart' show NutritionGoal;
import 'package:fitai_analyzer/providers/auth_notifier.dart';
import 'package:fitai_analyzer/providers/nutrition_chart_provider.dart';
import 'package:fitai_analyzer/providers/providers.dart';
import 'package:fitai_analyzer/providers/user_profile_notifier.dart';
import 'package:fitai_analyzer/ui/onboarding/nutrition_goal_screen.dart';
import 'package:fitai_analyzer/utils/date_utils.dart' show dateFilterAll, formatDateForDisplay;
import 'package:fitai_analyzer/services/gemini_api_key_service.dart';
import 'package:fitai_analyzer/services/gemini_service.dart';
import 'package:fitai_analyzer/services/nutrition_service.dart';
import 'package:fitai_analyzer/theme/app_card_theme.dart';
import 'package:fitai_analyzer/theme/app_theme.dart';
import 'package:fitai_analyzer/ui/widgets/date_filter_chips.dart';
import 'package:fitai_analyzer/ui/widgets/error_dialog.dart';
import 'package:fitai_analyzer/ui/widgets/loading_indicator.dart';
import 'package:fitai_analyzer/utils/meal_constants.dart';
import 'package:fitai_analyzer/ui/widgets/gemini_api_key_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb, TargetPlatform;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:fitai_analyzer/ui/widgets/NutritionChartCard.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import 'package:fitai_analyzer/utils/activity_utils.dart';

double? _macroNum(Map<String, dynamic>? m, List<String> keys) {
  if (m == null) return null;
  for (final k in keys) {
    final v = m[k];
    if (v is num) return v.toDouble();
    final s = v?.toString();
    if (s == null) continue;
    final parsed = double.tryParse(s);
    if (parsed != null) return parsed;
  }
  return null;
}

String get _galleryButtonLabel {
  if (kIsWeb) return 'Scegli dall\'archivio';
  switch (defaultTargetPlatform) {
    case TargetPlatform.iOS:
      return 'Scegli dalle foto';
    case TargetPlatform.android:
      return 'Scegli dalla galleria';
    case TargetPlatform.windows:
    case TargetPlatform.macOS:
    case TargetPlatform.linux:
      return 'Scegli dal PC';
    default:
      return 'Scegli immagine';
  }
}

bool get _isCameraSupported =>
    !kIsWeb &&
    (defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.android);

class AlimentazioneScreen extends ConsumerWidget {
  const AlimentazioneScreen({super.key});

  static final PageController _chartPageController = PageController();

  Future<void> _onAnalisiPiatto(
    BuildContext context,
    WidgetRef ref, {
    String? mealLabel,
    String? dateStr,
    ImageSource imageSource = ImageSource.camera,
  }) async {
    var uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      try {
        await ref.read(authNotifierProvider.notifier).signInAnonymously();
        uid = FirebaseAuth.instance.currentUser?.uid;
      } catch (e) {
        if (context.mounted) {
          showErrorDialog(context, 'Impossibile autenticarsi. Riprova. ($e)');
        }
        return;
      }
      if (uid == null && context.mounted) {
        showErrorDialog(context, 'Utente non autenticato.');
        return;
      }
    }

    final apiKeyService = ref.read(geminiApiKeyServiceProvider);
    if (!await apiKeyService.hasValidKey()) {
      if (!context.mounted) return;
      final saved = await showGeminiApiKeyDialog(context, ref);
      if (!saved || !context.mounted) return;
    }

    final source = _isCameraSupported ? imageSource : ImageSource.gallery;

    final picker = ImagePicker();
    final xFile = await picker.pickImage(source: source, imageQuality: 85);
    if (xFile == null || !context.mounted) return;

    final bytes = await xFile.readAsBytes();
    final mimeType = xFile.path.toLowerCase().endsWith('.png') ? 'image/png' : 'image/jpeg';

    if (!context.mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const AlertDialog(
        content: LoadingIndicator(message: 'Analisi nutrizione in corso...'),
      ),
    );

    try {
      final gemini = ref.read(geminiServiceProvider);
      final result = await gemini.analyzeNutritionFromImage(
        Uint8List.fromList(bytes),
        mimeType: mimeType,
      );

      if (context.mounted) Navigator.of(context).pop();

      if (result.containsKey('error')) {
        if (context.mounted) showErrorDialog(context, result['error'] ?? 'Errore');
        return;
      }

      if (context.mounted) {
        _showNutritionDialog(context, ref, result, uid: uid!, mealLabel: mealLabel, dateStr: dateStr);
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.of(context).pop();
        showErrorDialog(context, e.toString());
      }
    }
  }

  void _showNutritionDialog(
    BuildContext context,
    WidgetRef ref,
    Map<String, dynamic> nut, {
    required String uid,
    String? mealLabel,
    String? dateStr,
  }) {
    final advice = nut['advice'] ?? '';
    final foods = nut['foods'] as List<dynamic>? ?? [];

    showDialog(
      context: context,
      builder: (ctx) => _NutritionEditDialog(
        initialNut: nut,
        advice: advice,
        foods: foods,
        onSave: (modifiedNut) async {
          Navigator.of(ctx).pop();
          try {
            await ref.read(nutritionServiceProvider).saveToFirestore(
                  uid,
                  modifiedNut,
                  mealLabel: mealLabel,
                  date: dateStr != null ? DateTime.parse(dateStr) : null,
                );
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Analisi salvata')),
              );
            }
          } catch (e) {
            if (context.mounted) showErrorDialog(context, e.toString());
          }
        },
      ),
    );
  }

  void _showAggiungiPastoSheet(
    BuildContext context,
    WidgetRef ref,
    String mealLabel,
    String dateStr,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        final theme = Theme.of(ctx);
        final colorScheme = theme.colorScheme;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Aggiungi $mealLabel',
                  style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 24),
                if (_isCameraSupported)
                  FilledButton.icon(
                    onPressed: () {
                      Navigator.of(ctx).pop();
                      _onAnalisiPiatto(context, ref, mealLabel: mealLabel, dateStr: dateStr, imageSource: ImageSource.camera);
                    },
                    icon: const Icon(Icons.camera_alt),
                    label: const Text('Scatta foto'),
                  ),
                if (_isCameraSupported) const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    _onAnalisiPiatto(context, ref, mealLabel: mealLabel, dateStr: dateStr, imageSource: ImageSource.gallery);
                  },
                  icon: const Icon(Icons.photo_library),
                  label: Text(_galleryButtonLabel),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Inserimento manuale $mealLabel (in arrivo)')),
                    );
                  },
                  icon: Icon(Icons.edit, color: colorScheme.primary),
                  label: Text('Manualmente', style: TextStyle(color: colorScheme.primary)),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showMealDetailDialog(BuildContext context, MealModel meal) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(meal.displayTitle),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${meal.calories} kcal',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
              ),
              if (meal.timestamp.isNotEmpty)
                Text('Orario: ${meal.timestamp}'),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  _Chip(label: 'Proteine', value: '${meal.macros['pro']?.round() ?? 0}g'),
                  _Chip(label: 'Carbs', value: '${meal.macros['carb']?.round() ?? 0}g'),
                  _Chip(label: 'Grassi', value: '${meal.macros['fat']?.round() ?? 0}g'),
                ],
              ),
              if (meal.rawAiAnalysis.isNotEmpty) ...[
                const SizedBox(height: 16),
                const Text('Consiglio', style: TextStyle(fontWeight: FontWeight.bold)),
                Text(meal.rawAiAnalysis),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Chiudi'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final datesAsync = ref.watch(mealDatesProvider);
    final dates = datesAsync.valueOrNull ?? [];
    final selectedDate = ref.watch(selectedMealDateFilterProvider);
    final todayStr = DateTime.now().toIso8601String().split('T')[0];
    final displayDates = selectedDate == null
        ? [todayStr]
        : selectedDate == dateFilterAll
            ? (dates.isNotEmpty ? dates : [])
            : [selectedDate];

    final nutritionGoal = ref.watch(nutritionGoalProvider);
    final planAi = ref.watch(nutritionMealPlanAiStreamProvider).valueOrNull;
    final aiMacroGiornalieri = planAi?.macroGiornalieri;

    int calorieAssunte = 0;
    for (final d in displayDates) {
      final byType = ref.watch(mealsForDateByTypeProvider(d)).valueOrNull ?? {};
      for (final list in byType.values) {
        for (final m in list) {
          calorieAssunte += m.calories;
        }
      }
    }

    // Obiettivo "vero" usato sia nei grafici sia nella card: quello calcolato dall'IA.
    // Fallback: se il piano AI non esiste ancora, usiamo l'obiettivo configurato dall'utente.
    final obiettivoKcal = (_macroNum(aiMacroGiornalieri, ['kcal', 'calories']) ??
            nutritionGoal?.calorieTarget ??
            0)
        .round();
    final rimanenti = obiettivoKcal - calorieAssunte;

    return Scaffold(
      appBar: AppBar(title: const Text('Alimentazione')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (nutritionGoal == null)
              _NutritionOnboardingCard(
                onConfigure: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => NutritionGoalScreen(
                        onSuccess: () {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Obiettivo mangiare salvato')),
                            );
                            Navigator.of(context).pop();
                          }
                        },
                      ),
                    ),
                  );
                },
              )
            else
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$obiettivoKcal − $calorieAssunte = $rimanenti',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Obiettivo − Calorie assunte = Rimanenti',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                    ),
                  ],
                ),
              ),

            if (nutritionGoal != null) ...[
              const SizedBox(height: 16),
              Consumer(
                builder: (context, ref, _) {
                  final gen = ref.watch(nutritionMealPlanGeneratingProvider);
                  final planAsync = ref.watch(nutritionMealPlanAiStreamProvider);
                  final plan = planAsync.valueOrNull;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      FilledButton.tonalIcon(
                        onPressed: gen ? null : () => _onGenerateNutritionMealPlan(context, ref),
                        icon: gen
                            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.restaurant_menu),
                        label: Text(
                          gen
                              ? 'Generazione piano...'
                              : (plan?.hasAnyObjective == true ? 'Aggiorna obiettivi pasti (AI)' : 'Genera obiettivi pasti (AI)'),
                        ),
                      ),
                      if (plan != null && plan.macroGiornalieri.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Text(
                          _macroSummaryLine(plan.macroGiornalieri),
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                              ),
                        ),
                      ],
                    ],
                  );
                },
              ),
            ],

            const SizedBox(height: 20),
            Text(
              'Date',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 8),
            DateFilterChips(
              selectedDate: selectedDate,
              onDateSelected: (d) => ref.read(selectedMealDateFilterProvider.notifier).state = d,
            ),

            const SizedBox(height: 20),
            if (displayDates.isEmpty)
              ..._buildMealCardsForDate(context, ref, todayStr)
            else
              ...displayDates.expand((dateKey) => [
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(
                        formatDateForDisplay(dateKey),
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              color: Theme.of(context).colorScheme.primary,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                    ),
                    ..._buildMealCardsForDate(context, ref, dateKey),
                    const SizedBox(height: 24),
                  ]),

            const SizedBox(height: 24),
            _buildWeeklyChartsSection(context, ref, nutritionGoal, aiMacroGiornalieri),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  static String _macroSummaryLine(Map<String, dynamic> m) {
    num? n(String a, String b) {
      final v = m[a] ?? m[b];
      if (v is num) return v;
      return num.tryParse(v?.toString() ?? '');
    }

    final p = n('proteine_g', 'protein_g');
    final c = n('carboidrati_g', 'carbs_g');
    final f = n('grassi_g', 'fat_g');
    final k = n('kcal', 'calories');
    final parts = <String>[];
    if (p != null) parts.add('P: ${p.round()} g');
    if (c != null) parts.add('C: ${c.round()} g');
    if (f != null) parts.add('G: ${f.round()} g');
    if (k != null) parts.add('${k.round()} kcal');
    return parts.isEmpty ? '' : 'Macro giornalieri (da piano AI): ${parts.join(' · ')}';
  }

  List<Widget> _buildMealCardsForDate(BuildContext context, WidgetRef ref, String dateStr) {
    return [
      for (var i = 0; i < MealConstants.mealTypes.length; i++) ...[
        if (i > 0) const SizedBox(height: 16),
        _MealCardForDate(
          dateStr: dateStr,
          label: MealConstants.mealTypes[i],
          onTap: () => _showAggiungiPastoSheet(context, ref, MealConstants.mealLabels[i], dateStr),
          onMealTap: (meal) => _showMealDetailDialog(context, meal),
        ),
        _MealAiObjectivesCard(pastoKey: MealConstants.mealLabels[i]),
      ],
    ];
  }

  // ====================== SEZIONE GRAFICO IN BASSO ======================
  Widget _buildWeeklyChartsSection(
    BuildContext context,
    WidgetRef ref,
    NutritionGoal? nutritionGoal,
    Map<String, dynamic>? aiMacroGiornalieri,
  ) {
    final cs = Theme.of(context).colorScheme;
    final profile = ref.watch(userProfileNotifierProvider).profile;
    final chartAsync = ref.watch(nutritionChartDataProvider);

    final kcalTarget = _macroNum(aiMacroGiornalieri, ['kcal', 'calories']) ??
        nutritionGoal?.calorieTarget ??
        2000.0;

    final proteinTarget = _macroNum(aiMacroGiornalieri, ['proteine_g', 'protein_g']) ??
        (nutritionGoal != null && profile != null && profile.weightKg > 0
            ? nutritionGoal.proteinGPerKg * profile.weightKg
            : 150.0);

    final fatTarget = _macroNum(aiMacroGiornalieri, ['grassi_g', 'fat_g']) ??
        (nutritionGoal != null &&
                nutritionGoal.calorieTarget > 0 &&
                nutritionGoal.fatPercentage > 0
            ? (nutritionGoal.calorieTarget * nutritionGoal.fatPercentage / 100) / 9.0
            : 70.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Trend Settimanale Nutrizione',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        chartAsync.when(
          data: (chartData) {
            final goals = <NutrientGoal>[
              NutrientGoal(
                title: 'Calorie',
                unit: 'kcal',
                target: kcalTarget,
                color: Colors.blueAccent,
                weeklyData: chartData.caloriesData,
              ),
              NutrientGoal(
                title: 'Proteine',
                unit: 'g',
                target: proteinTarget,
                color: Colors.purpleAccent,
                weeklyData: chartData.proteinData,
              ),
              NutrientGoal(
                title: 'Grassi',
                unit: 'g',
                target: fatTarget,
                color: Colors.orangeAccent,
                weeklyData: chartData.fatData,
              ),
            ];

            return SizedBox(
              height: 340,
              child: ScrollConfiguration(
                behavior: MyCustomScrollBehavior(),
                child: PageView.builder(
                  controller: AlimentazioneScreen._chartPageController,
                  physics: const BouncingScrollPhysics(),
                  itemCount: goals.length,
                  itemBuilder: (context, index) {
                    return AnimatedBuilder(
                      animation: AlimentazioneScreen._chartPageController,
                      builder: (context, child) {
                        double value = 0.0;
                        if (AlimentazioneScreen._chartPageController.position.haveDimensions) {
                          value = (AlimentazioneScreen._chartPageController.page ?? 0) - index;
                        } else {
                          value = 0.0 - index;
                        }
                        final scale = (1 - (value.abs() * 0.15)).clamp(0.85, 1.0);
                        final opacity = (1 - (value.abs() * 0.4)).clamp(0.5, 1.0);

                        return Transform.scale(
                          scale: scale,
                          child: Opacity(
                            opacity: opacity,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
                              child: NutritionChartCard(goal: goals[index]),
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            );
          },
          loading: () => const SizedBox(
            height: 340,
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (error, stack) => SizedBox(
            height: 340,
            child: Center(child: Text('Errore caricamento grafico: $error')),
          ),
        ),
        const SizedBox(height: 12),
        Center(  
          child: SmoothPageIndicator(
            controller: AlimentazioneScreen._chartPageController,
            count: 3,
            effect: ExpandingDotsEffect(
              dotHeight: 8,
              dotWidth: 8,
              activeDotColor: cs.primary,
              dotColor: cs.outlineVariant,
              expansionFactor: 3,
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _onGenerateNutritionMealPlan(BuildContext context, WidgetRef ref) async {
    var uid = ref.read(authNotifierProvider).user?.uid;
    uid ??= FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      if (context.mounted) showErrorDialog(context, 'Utente non autenticato.');
      return;
    }

    final apiKeyService = ref.read(geminiApiKeyServiceProvider);
    if (!await apiKeyService.hasValidKey()) {
      if (!context.mounted) return;
      final saved = await showGeminiApiKeyDialog(context, ref);
      if (!saved || !context.mounted) return;
    }

    ref.read(nutritionMealPlanGeneratingProvider.notifier).state = true;
    try {
      await ref.read(nutritionMealPlanServiceProvider).generateAndSave(uid);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Piano alimentare AI salvato')),
        );
      }
    } catch (e) {
      if (context.mounted) showErrorDialog(context, e.toString());
    } finally {
      ref.read(nutritionMealPlanGeneratingProvider.notifier).state = false;
    }
  }
}

// ====================== WIDGETS AUSILIARI ======================
class _NutritionOnboardingCard extends StatelessWidget {
  const _NutritionOnboardingCard({required this.onConfigure});

  final VoidCallback onConfigure;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      elevation: 0,
      color: cs.primaryContainer,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.restaurant_menu, color: cs.onPrimaryContainer, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Obiettivo Mangiare',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: cs.onPrimaryContainer,
                        ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Imposta preferenze, obiettivo nutrizionale e target calorico. Poi vedrai qui obiettivo giornaliero, calorie assunte e kcal rimanenti.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: cs.onPrimaryContainer.withValues(alpha: 0.92),
                  ),
            ),
            const SizedBox(height: 16),
            FilledButton(onPressed: onConfigure, child: const Text('Configura obiettivo mangiare')),
          ],
        ),
      ),
    );
  }
}

class _MealCardForDate extends ConsumerWidget {
  const _MealCardForDate({
    required this.dateStr,
    required this.label,
    required this.onTap,
    required this.onMealTap,
  });

  final String dateStr;
  final String label;
  final VoidCallback onTap;
  final void Function(MealModel meal) onMealTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mealsAsync = ref.watch(mealsForDateByTypeProvider(dateStr));
    final meals = mealsAsync.valueOrNull?[label] ?? [];
    return _MealCard(
      label: label,
      meals: meals,
      onTap: onTap,
      onMealTap: onMealTap,
    );
  }
}

class _MealCard extends StatelessWidget {
  const _MealCard({
    required this.label,
    required this.meals,
    required this.onTap,
    required this.onMealTap,
  });

  final String label;
  final List<MealModel> meals;
  final VoidCallback onTap;
  final void Function(MealModel meal) onMealTap;

  @override
  Widget build(BuildContext context) {
    final cardTheme = Theme.of(context).extension<AppCardTheme>()!;

    return Container(
      decoration: cardTheme.gradientDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        label,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              color: cardTheme.contentColor,
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: cardTheme.contentColor.withValues(alpha: 0.3),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.add, color: cardTheme.contentColor, size: 24),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (meals.isNotEmpty) ...[
            Divider(height: 1, color: cardTheme.contentColor.withValues(alpha: 0.4)),
            ...meals.map((meal) => _MealTile(meal: meal, onTap: () => onMealTap(meal))),
          ],
        ],
      ),
    );
  }
}

class _MealTile extends StatelessWidget {
  const _MealTile({required this.meal, required this.onTap});

  final MealModel meal;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cardTheme = Theme.of(context).extension<AppCardTheme>()!;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  meal.displayTitle,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: cardTheme.contentColor),
                ),
              ),
              Text(
                '${meal.calories} kcal',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: cardTheme.contentColor,
                    ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.chevron_right, color: cardTheme.contentColorMuted, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

class _NutritionEditDialog extends StatefulWidget {
  const _NutritionEditDialog({
    required this.initialNut,
    required this.advice,
    required this.foods,
    required this.onSave,
  });

  final Map<String, dynamic> initialNut;
  final String advice;
  final List<dynamic> foods;
  final void Function(Map<String, dynamic> modifiedNut) onSave;

  @override
  State<_NutritionEditDialog> createState() => _NutritionEditDialogState();
}

class _NutritionEditDialogState extends State<_NutritionEditDialog> {
  late int _calories;
  late int _protein;
  late int _carbs;
  late int _fat;
  late int _sugar;

  @override
  void initState() {
    super.initState();
    _calories = (widget.initialNut['total_calories'] ?? widget.initialNut['calories'] ?? 0) as int;
    _protein = (widget.initialNut['protein_g'] ?? widget.initialNut['protein'] ?? 0) as int;
    _carbs = (widget.initialNut['carbs_g'] ?? widget.initialNut['carbs'] ?? 0) as int;
    _fat = (widget.initialNut['fat_g'] ?? widget.initialNut['fat'] ?? 0) as int;
    _sugar = (widget.initialNut['sugar_g'] ?? widget.initialNut['sugar'] ?? 0) as int;
  }

  Map<String, dynamic> _buildModifiedNut() {
    final m = Map<String, dynamic>.from(widget.initialNut);
    m['total_calories'] = _calories;
    m['protein_g'] = _protein;
    m['carbs_g'] = _carbs;
    m['fat_g'] = _fat;
    m['sugar_g'] = _sugar;
    return m;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Analisi nutrizione'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildStepper('Calorie', _calories, (v) => setState(() => _calories = v.clamp(0, 9999)), suffix: ' kcal'),
            _buildStepper('Proteine', _protein, (v) => setState(() => _protein = v.clamp(0, 999))),
            _buildStepper('Carbs', _carbs, (v) => setState(() => _carbs = v.clamp(0, 999))),
            _buildStepper('Grassi', _fat, (v) => setState(() => _fat = v.clamp(0, 999))),
            _buildStepper('Zuccheri', _sugar, (v) => setState(() => _sugar = v.clamp(0, 999))),
            if (widget.foods.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Text('Alimenti', style: TextStyle(fontWeight: FontWeight.bold)),
              ...widget.foods.take(8).map((e) {
                final m = e is Map ? e as Map<String, dynamic> : <String, dynamic>{};
                return Text('• ${m['name'] ?? '?'}');
              }),
            ],
            if (widget.advice.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Text('Consiglio', style: TextStyle(fontWeight: FontWeight.bold)),
              Text(widget.advice),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Annulla')),
        FilledButton(onPressed: () => widget.onSave(_buildModifiedNut()), child: const Text('Salva')),
      ],
    );
  }

  Widget _buildStepper(String label, int value, ValueChanged<int> onChanged, {String suffix = 'g'}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          SizedBox(width: 90, child: Text(label)),
          IconButton.filled(onPressed: () => onChanged(value - 1), icon: const Icon(Icons.exposure_minus_1)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text('$value$suffix', style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
          IconButton.filled(onPressed: () => onChanged(value + 1), icon: const Icon(Icons.add)),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Chip(label: Text('$label: $value'));
  }
}

class _MealAiObjectivesCard extends ConsumerWidget {
  const _MealAiObjectivesCard({required this.pastoKey});

  final String pastoKey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plan = ref.watch(nutritionMealPlanAiStreamProvider).valueOrNull;
    if (plan == null || !plan.hasAnyObjective) return const SizedBox.shrink();

    final List<String> items = switch (pastoKey) {
      'colazione' => plan.obiettiviColazione,
      'cena' => plan.obiettiviCena,
      _ => plan.obiettiviPranzo,
    };

    if (items.isEmpty) return const SizedBox.shrink();

    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Material(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.flag_outlined, size: 18, color: cs.primary),
                  const SizedBox(width: 8),
                  Text('Obiettivi per questo pasto', style: Theme.of(context).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600)),
                ],
              ),
              const SizedBox(height: 8),
              for (final t in items)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    children: [
                      Text('• ', style: TextStyle(color: cs.primary, fontWeight: FontWeight.bold)),
                      Expanded(child: Text(t, style: Theme.of(context).textTheme.bodySmall)),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}