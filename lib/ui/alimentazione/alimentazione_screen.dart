import 'dart:typed_data';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:fitai_analyzer/models/meal_model.dart';
import 'package:fitai_analyzer/providers/auth_notifier.dart';
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

/// Su Windows/macOS/Linux la fotocamera non è supportata da image_picker.
bool get _isCameraSupported =>
    !kIsWeb &&
    (defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.android);

/// Pagina dedicata all'alimentazione.
/// Qui andranno tutte le funzionalità: analizza piatto, storico pasti, ecc.
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
      // Su iOS dopo reload la sessione può non essere ancora ripristinata.
      // Se l'utente va direttamente su Alimentazione senza Strava, non ha mai fatto login.
      // In entrambi i casi: tenta login anonimo (come per Strava).
      try {
        await ref.read(authNotifierProvider.notifier).signInAnonymously();
        uid = FirebaseAuth.instance.currentUser?.uid;
      } catch (e) {
        if (context.mounted) {
          showErrorDialog(
            context,
            'Impossibile autenticarsi. Riprova. ($e)',
          );
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

    // Su desktop (Windows/macOS/Linux) la fotocamera non è supportata.
    final source = _isCameraSupported
        ? imageSource
        : ImageSource.gallery;

    final picker = ImagePicker();
    final xFile = await picker.pickImage(
      source: source,
      imageQuality: 85,
    );
    if (xFile == null || !context.mounted) return;

    final bytes = await xFile.readAsBytes();
    final mimeType = xFile.path.toLowerCase().endsWith('.png')
        ? 'image/png'
        : 'image/jpeg';

    if (!context.mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        content: const LoadingIndicator(message: 'Analisi nutrizione in corso...'),
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
        _showNutritionDialog(context, ref, result,
            uid: uid!, mealLabel: mealLabel, dateStr: dateStr);
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
                const SnackBar(
                  content: Text('Analisi salvata'),
                ),
              );
            }
          } catch (e) {
            if (context.mounted) {
              showErrorDialog(context, e.toString());
            }
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
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
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
                  style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onSurface,
                      ),
                ),
                const SizedBox(height: 24),
                if (_isCameraSupported)
                  FilledButton.icon(
                    onPressed: () {
                      Navigator.of(ctx).pop();
                      _onAnalisiPiatto(context, ref,
                          mealLabel: mealLabel,
                          dateStr: dateStr,
                          imageSource: ImageSource.camera);
                    },
                    icon: const Icon(Icons.camera_alt),
                    label: const Text('Scatta foto'),
                    style: FilledButton.styleFrom(
                      backgroundColor: colorScheme.primary,
                      foregroundColor: colorScheme.onPrimary,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                if (_isCameraSupported) const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    _onAnalisiPiatto(context, ref,
                        mealLabel: mealLabel,
                        dateStr: dateStr,
                        imageSource: ImageSource.gallery);
                  },
                  icon: const Icon(Icons.photo_library),
                  label: Text(_galleryButtonLabel),
                  style: FilledButton.styleFrom(
                    backgroundColor: colorScheme.primary,
                    foregroundColor: colorScheme.onPrimary,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Inserimento manuale $mealLabel (in arrivo)'),
                      ),
                    );
                  },
                  icon: Icon(Icons.edit, color: colorScheme.primary),
                  label: Text('Manualmente', style: TextStyle(color: colorScheme.primary)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: colorScheme.primary,
                    side: BorderSide(color: colorScheme.primary),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
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
                Text(
                  'Orario: ${meal.timestamp}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
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
                Text(
                  'Consiglio',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 4),
                Text(
                  meal.rawAiAnalysis,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
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

    // Somma calorie assunte per le date visualizzate
    int calorieAssunte = 0;
    for (final d in displayDates) {
      final byType = ref.watch(mealsForDateByTypeProvider(d)).valueOrNull ?? {};
      for (final list in byType.values) {
        for (final m in list) {
          calorieAssunte += m.calories;
        }
      }
    }

    final obiettivoKcal = nutritionGoal?.calorieTarget.round();
    final rimanenti =
        obiettivoKcal != null ? obiettivoKcal - calorieAssunte : null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Alimentazione'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (nutritionGoal == null)
              _NutritionOnboardingCard(
                onConfigure: () {
                  Navigator.of(context).push<void>(
                    MaterialPageRoute<void>(
                      builder: (_) => NutritionGoalScreen(
                        onSuccess: () {
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Obiettivo mangiare salvato'),
                            ),
                          );
                          Navigator.of(context).pop();
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
                            color: Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant,
                          ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                height: 300,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  children: [
                    NutritionChartCard(
                      goal: NutrientGoal(
                        title: "Calorie", unit: "kcal", target: 2400, color: Colors.blueAccent,
                        weeklyData: [DailyNutrient("L", 2100), DailyNutrient("M", 2500), DailyNutrient("M", 1900), DailyNutrient("G", 2400), DailyNutrient("V", 2200), DailyNutrient("S", 2800), DailyNutrient("D", 2300)],
                      ),
                    ),
                    NutritionChartCard(
                      goal: NutrientGoal(
                        title: "Proteine", unit: "g", target: 150, color: Colors.purpleAccent,
                        weeklyData: [DailyNutrient("L", 140), DailyNutrient("M", 160), DailyNutrient("M", 150), DailyNutrient("G", 155), DailyNutrient("V", 145), DailyNutrient("S", 130), DailyNutrient("D", 150)],
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
                        onPressed: gen
                            ? null
                            : () => _onGenerateNutritionMealPlan(context, ref),
                        icon: gen
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.restaurant_menu),
                        label: Text(
                          gen
                              ? 'Generazione piano...'
                              : (plan?.hasAnyObjective == true
                                  ? 'Aggiorna obiettivi pasti (AI)'
                                  : 'Genera obiettivi pasti (AI)'),
                        ),
                      ),
                      if (plan != null && plan.macroGiornalieri.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Text(
                          _macroSummaryLine(plan.macroGiornalieri),
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant,
                                  ),
                        ),
                      ],
                      if (plan != null &&
                          plan.aderenzaScore != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          'Aderenza piano (stima): ${plan.aderenzaScore}%',
                          style:
                              Theme.of(context).textTheme.labelSmall?.copyWith(
                                    color: Theme.of(context).colorScheme.primary,
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
              onDateSelected: (d) =>
                  ref.read(selectedMealDateFilterProvider.notifier).state = d,
            ),
            const SizedBox(height: 20),
            if (displayDates.isEmpty)
              ..._buildMealCardsForDate(
                context,
                ref,
                DateTime.now().toIso8601String().split('T')[0],
              )
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
           _buildWeeklyChartsSection(context, ref, nutritionGoal),
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

  Future<void> _onGenerateNutritionMealPlan(
    BuildContext context,
    WidgetRef ref,
  ) async {
    var uid = ref.read(authNotifierProvider).user?.uid;
    uid ??= FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      if (context.mounted) {
        showErrorDialog(context, 'Utente non autenticato.');
      }
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

  List<Widget> _buildMealCardsForDate(
    BuildContext context,
    WidgetRef ref,
    String dateStr,
  ) {
    return [
      for (var i = 0; i < MealConstants.mealTypes.length; i++) ...[
        if (i > 0) const SizedBox(height: 16),
        _MealCardForDate(
          dateStr: dateStr,
          label: MealConstants.mealTypes[i],
          onTap: () => _showAggiungiPastoSheet(
            context,
            ref,
            MealConstants.mealLabels[i],
            dateStr,
          ),
          onMealTap: (meal) => _showMealDetailDialog(context, meal),
        ),
        _MealAiObjectivesCard(pastoKey: MealConstants.mealLabels[i]),
      ],
    ];
  }
}

class NutritionPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    // Esempio dati basati su Progetto Invictus (es. 70kg utente)
    final List<NutrientGoal> myGoals = [
      NutrientGoal(
        title: "Calorie",
        unit: "kcal",
        target: 2400,
        color: Colors.blueAccent,
        weeklyData: [DailyNutrient("L", 2100), DailyNutrient("M", 2500), DailyNutrient("M", 1900), DailyNutrient("G", 2400), DailyNutrient("V", 2200), DailyNutrient("S", 2800), DailyNutrient("D", 2300)],
      ),
      NutrientGoal(
        title: "Proteine",
        unit: "g",
        target: 150, // 2.1g * kg
        color: Colors.purpleAccent,
        weeklyData: [DailyNutrient("L", 140), DailyNutrient("M", 160), DailyNutrient("M", 150), DailyNutrient("G", 155), DailyNutrient("V", 145), DailyNutrient("S", 130), DailyNutrient("D", 150)],
      ),
      NutrientGoal(
        title: "Grassi",
        unit: "g",
        target: 70, // 1g * kg
        color: Colors.orangeAccent,
        weeklyData: [DailyNutrient("L", 65), DailyNutrient("M", 80), DailyNutrient("M", 60), DailyNutrient("G", 70), DailyNutrient("V", 72), DailyNutrient("S", 90), DailyNutrient("D", 70)],
      ),
    ];

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.all(20.0),
              child: Text("Alimentazione", style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)),
            ),
            // IL CONTENITORE DELLO SCROLL
            SizedBox(
              height: 350, // Altezza della card
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(), // Effetto rimbalzo iOS style
                itemCount: myGoals.length,
                itemBuilder: (context, index) {
                  return NutritionChartCard(goal: myGoals[index]);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Obiettivi operativi Gemini sotto la card Colazione / Pranzo / Cena.
class _MealAiObjectivesCard extends ConsumerWidget {
  const _MealAiObjectivesCard({required this.pastoKey});

  /// `colazione` | `pranzo` | `cena` (allineato a [MealConstants.mealLabels]).
  final String pastoKey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ng = ref.watch(nutritionGoalProvider);
    if (ng == null) return const SizedBox.shrink();

    final plan = ref.watch(nutritionMealPlanAiStreamProvider).valueOrNull;
    if (plan == null || !plan.hasAnyObjective) {
      return const SizedBox.shrink();
    }

    final List<String> items;
    switch (pastoKey) {
      case 'colazione':
        items = plan.obiettiviColazione;
        break;
      case 'cena':
        items = plan.obiettiviCena;
        break;
      case 'pranzo':
      default:
        items = plan.obiettiviPranzo;
        break;
    }
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
                  Text(
                    'Obiettivi per questo pasto',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: cs.onSurface,
                        ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              for (final t in items)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '• ',
                        style: TextStyle(
                          color: cs.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Expanded(
                        child: Text(
                          t,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                height: 1.35,
                                color: cs.onSurfaceVariant,
                              ),
                        ),
                      ),
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

/// Invito a completare sub-onboarding Obiettivo Mangiare (al posto dei numeri placeholder).
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
              'Imposta preferenze, obiettivo nutrizionale e target calorico '
              '(evidenza CREA / ISSN). Poi vedrai qui obiettivo giornaliero, '
              'calorie assunte e kcal rimanenti con i tuoi dati reali.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: cs.onPrimaryContainer.withValues(alpha: 0.92),
                  ),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: onConfigure,
              child: const Text('Configura obiettivo mangiare'),
            ),
          ], 
        ),
      ),
    );


  }
}


/// Card pasto per una data specifica, legge i pasti dal provider.
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

/// Card pasto (Colazione/Pranzo/Cena) con lista piatti e pulsante aggiungi.
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
                      child: Icon(
                        Icons.add,
                        color: cardTheme.contentColor,
                        size: 24,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (meals.isNotEmpty) ...[
            Divider(
              height: 1,
              color: cardTheme.contentColor.withValues(alpha: 0.4),
            ),
            ...meals.map((meal) => _MealTile(
                  meal: meal,
                  onTap: () => onMealTap(meal),
                )),
          ],
        ],
      ),
    );
  }
}

/// Riga singolo piatto: titolo + calorie, tappabile per dettagli.
class _MealTile extends StatelessWidget {
  const _MealTile({
    required this.meal,
    required this.onTap,
  });

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
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: cardTheme.contentColor,
                      ),
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
              Icon(
                Icons.chevron_right,
                color: cardTheme.contentColorMuted,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Dialog analisi nutrizione con controlli +/- per modificare i valori.
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
    _calories = _num(widget.initialNut['total_calories'] ?? widget.initialNut['calories'] ?? 0).round();
    _protein = _num(widget.initialNut['protein_g'] ?? widget.initialNut['protein'] ?? 0).round();
    _carbs = _num(widget.initialNut['carbs_g'] ?? widget.initialNut['carbs'] ?? 0).round();
    _fat = _num(widget.initialNut['fat_g'] ?? widget.initialNut['fat'] ?? 0).round();
    _sugar = _num(widget.initialNut['sugar_g'] ?? widget.initialNut['sugar'] ?? 0).round();
  }

  double _num(dynamic v) => (v is num) ? v.toDouble() : double.tryParse(v.toString()) ?? 0;

  Map<String, dynamic> _buildModifiedNut() {
    final m = Map<String, dynamic>.from(widget.initialNut);
    m['total_calories'] = _calories;
    m['protein_g'] = _protein;
    m['carbs_g'] = _carbs;
    m['fat_g'] = _fat;
    m['sugar_g'] = _sugar;
    return m;
  }

  Widget _buildStepper(String label, int value, ValueChanged<int> onChanged, {String suffix = 'g'}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          SizedBox(
            width: 90,
            child: Text(label, style: Theme.of(context).textTheme.bodyMedium),
          ),
          IconButton.filled(
            onPressed: () => onChanged(value - 1),
            icon: const Icon(Icons.remove),
            style: IconButton.styleFrom(
              padding: const EdgeInsets.all(8),
              minimumSize: const Size(36, 36),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: SizedBox(
              width: 48,
              child: Text(
                '$value$suffix',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ),
          ),
          IconButton.filled(
            onPressed: () => onChanged(value + 1),
            icon: const Icon(Icons.add),
            style: IconButton.styleFrom(
              padding: const EdgeInsets.all(8),
              minimumSize: const Size(36, 36),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Analisi nutrizione'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildStepper('Calorie', _calories.clamp(0, 9999), (v) {
              setState(() => _calories = v.clamp(0, 9999));
            }, suffix: ' kcal'),
            _buildStepper('Proteine', _protein.clamp(0, 999), (v) {
              setState(() => _protein = v.clamp(0, 999));
            }),
            _buildStepper('Carbs', _carbs.clamp(0, 999), (v) {
              setState(() => _carbs = v.clamp(0, 999));
            }),
            _buildStepper('Grassi', _fat.clamp(0, 999), (v) {
              setState(() => _fat = v.clamp(0, 999));
            }),
            _buildStepper('Zuccheri', _sugar.clamp(0, 999), (v) {
              setState(() => _sugar = v.clamp(0, 999));
            }),
            if (widget.foods.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(
                'Alimenti',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 4),
              ...widget.foods.take(8).map((e) {
                final m = e is Map ? e as Map<String, dynamic> : <String, dynamic>{};
                final name = m['name'] ?? '?';
                final cals = m['calories'];
                final portion = m['portion'];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    '• $name${cals != null ? ' (${(cals as num).round()} kcal)' : ''}${portion != null ? ' - $portion' : ''}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                );
              }),
            ],
            if (widget.advice.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(
                'Consiglio',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 4),
              Text(
                widget.advice,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Annulla'),
        ),
        FilledButton(
          onPressed: () => widget.onSave(_buildModifiedNut()),
          child: const Text('Salva'),
        ),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Chip(
      label: Text('$label: $value'),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }
}
Widget _buildWeeklyChartsSection(BuildContext context, WidgetRef ref, dynamic nutritionGoal) {
  final cs = Theme.of(context).colorScheme;
  
  // Dati reali: qui dovresti mappare i dati dal tuo provider. 
  // Per ora manteniamo la struttura per il test grafico.
  final List<NutrientGoal> myGoals = [
    NutrientGoal(
      title: "Calorie", unit: "kcal", target: nutritionGoal?.calorieTarget ?? 2000, color: Colors.blueAccent,
      weeklyData: [DailyNutrient("L", 2100), DailyNutrient("M", 2500), DailyNutrient("M", 1900), DailyNutrient("G", 2400), DailyNutrient("V", 2200), DailyNutrient("S", 2800), DailyNutrient("D", 2300)],
    ),
    NutrientGoal(
      title: "Proteine", unit: "g", target: 150, color: Colors.purpleAccent,
      weeklyData: [DailyNutrient("L", 140), DailyNutrient("M", 160), DailyNutrient("M", 150), DailyNutrient("G", 155), DailyNutrient("V", 145), DailyNutrient("S", 130), DailyNutrient("D", 150)],
    ),
    NutrientGoal(
      title: "Grassi", unit: "g", target: 70, color: Colors.orangeAccent,
      weeklyData: [DailyNutrient("L", 65), DailyNutrient("M", 80), DailyNutrient("M", 60), DailyNutrient("G", 70), DailyNutrient("V", 72), DailyNutrient("S", 90), DailyNutrient("D", 70)],
    ),
  ];

 return Column(
  children: [
    SizedBox(
      height: 340, // Un po' più di altezza per gestire lo scaling delle card
      child: ScrollConfiguration(
        // Utilizziamo la classe che hai messo in activity_utility.dart
        behavior: MyCustomScrollBehavior(), 
        child: PageView.builder(
          controller: AlimentazioneScreen._chartPageController,
          physics: const BouncingScrollPhysics(),
          itemCount: myGoals.length,
          itemBuilder: (context, index) {
            return AnimatedBuilder(
              animation: AlimentazioneScreen._chartPageController,
              builder: (context, child) {
                // Calcoliamo la posizione della pagina per l'effetto visivo
                double value = 0.0;
                if (AlimentazioneScreen._chartPageController.position.haveDimensions) {
                  value = (AlimentazioneScreen._chartPageController.page ?? 0) - index;
                } else {
                  // Fallback iniziale prima che il controller sia pronto
                  value = (0.0 - index);
                }

                // Logica Stack: 
                // La card attiva è scala 1.0, quelle "sotto" si rimpiccioliscono (0.9)
                // e svaniscono leggermente (opacity)
                double scale = (1 - (value.abs() * 0.15)).clamp(0.85, 1.0);
                double opacity = (1 - (value.abs() * 0.4)).clamp(0.5, 1.0);

                return Transform.scale(
                  scale: scale,
                  child: Opacity(
                    opacity: opacity,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
                      child: NutritionChartCard(goal: myGoals[index]),
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    ),
    const SizedBox(height: 12),
    // Indicatori di pagina (Puntini)
    SmoothPageIndicator(
      controller: AlimentazioneScreen._chartPageController,
      count: myGoals.length,
      effect: ExpandingDotsEffect(
        dotHeight: 8,
        dotWidth: 8,
        activeDotColor: cs.primary,
        dotColor: cs.outlineVariant,
        expansionFactor: 3, // Rende il puntino attivo più lungo
      ),
    ),
  ],
);
}
