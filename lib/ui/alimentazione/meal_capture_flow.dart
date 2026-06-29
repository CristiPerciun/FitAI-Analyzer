import 'dart:typed_data';

import 'package:fitai_analyzer/app.dart';
import 'package:fitai_analyzer/providers/auth_notifier.dart';
import 'package:fitai_analyzer/providers/nutrition_chart_provider.dart';
import 'package:fitai_analyzer/providers/nutrition_meal_edit_provider.dart';
import 'package:fitai_analyzer/providers/pending_meal_analysis_provider.dart';
import 'package:fitai_analyzer/providers/providers.dart';
import 'package:fitai_analyzer/routes/app_router.dart';
import 'package:fitai_analyzer/services/nutrition_service.dart';
import 'package:fitai_analyzer/ui/alimentazione/nutrition_meal_analysis_screen.dart';
import 'package:fitai_analyzer/ui/home/widgets/manual_entry_dialog.dart';
import 'package:fitai_analyzer/ui/widgets/ai_backend_key_gate.dart';
import 'package:fitai_analyzer/ui/widgets/error_dialog.dart';
import 'package:fitai_analyzer/utils/image_picker_utils.dart';
import 'package:fitai_analyzer/utils/meal_constants.dart';
import 'package:fitai_analyzer/utils/nutrition_parsing_utils.dart';
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

/// Flow condiviso "Aggiungi pasto" usato da:
/// - pagina Alimentazione (bottoni Colazione/Pranzo/Cena/Spuntino +),
/// - tile Alimentazione in Home (quando il piano AI è già stato generato).
///
/// Tutta la logica di selezione foto, analisi Gemini, salvataggio Firestore,
/// gestione "pending meal analysis" e inserimento manuale è centralizzata qui
/// per evitare duplicazione tra Home e Alimentazione.

/// Apre il bottom sheet "Aggiungi pasto" con le opzioni:
/// - Scatta foto (dove supportato),
/// - Galleria / archivio,
/// - Inserimento manuale (descrivi cosa hai mangiato).
///
/// - [mealLabel] è la chiave lowercase ('colazione' | 'pranzo' | 'cena' | 'spuntino').
///   Se null, viene dedotta automaticamente dall'ora corrente.
/// - [dateStr] è la data ISO (YYYY-MM-DD). Se null, usa oggi.
Future<void> showAddMealSheet(
  BuildContext context,
  WidgetRef ref, {
  String? mealLabel,
  String? dateStr,
}) async {
  final effectiveLabel = (mealLabel != null && mealLabel.isNotEmpty)
      ? mealLabel
      : MealConstants.mealLabelForTime(DateTime.now());
  final effectiveDate =
      dateStr ?? DateTime.now().toIso8601String().split('T')[0];

  await showModalBottomSheet<void>(
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
                'Aggiungi ${MealConstants.toMealType(effectiveLabel)}',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 24),
              if (_isCameraSupported)
                FilledButton.icon(
                  onPressed: () {
                    // Su web/PWA: avvia _analyzeMealFromPicker (che chiama
                    // pickImage come prima op.) PRIMA di Navigator.pop(),
                    // così il browser riceve input.click() ancora dentro il
                    // gesto utente.
                    _analyzeMealFromPicker(
                      context,
                      ref,
                      mealLabel: effectiveLabel,
                      dateStr: effectiveDate,
                      imageSource: ImageSource.camera,
                    );
                    Navigator.of(ctx).pop();
                  },
                  icon: const Icon(Icons.camera_alt),
                  label: const Text('Scatta foto'),
                ),
              if (_isCameraSupported) const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: () {
                  _analyzeMealFromPicker(
                    context,
                    ref,
                    mealLabel: effectiveLabel,
                    dateStr: effectiveDate,
                    imageSource: ImageSource.gallery,
                  );
                  Navigator.of(ctx).pop();
                },
                icon: const Icon(Icons.photo_library),
                label: Text(_galleryButtonLabel),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () async {
                  // Su web/PWA: apri l'input subito, dentro il gesto utente
                  // (come pickImage per galleria/camera), prima di await e
                  // prima di chiudere il bottom sheet.
                  final text = await showManualEntryDialog(ctx);
                  if (!ctx.mounted) return;
                  Navigator.of(ctx).pop();

                  if (text == null || text.trim().isEmpty || !context.mounted) {
                    return;
                  }
                  if (!await ensureActiveAiBackendHasKey(context, ref)) {
                    return;
                  }
                  if (!context.mounted) return;

                  final uid = await ensureNutritionUid(context, ref);
                  if (uid == null || !context.mounted) return;

                  _analyzeMealFromManualText(
                    ref,
                    text: text.trim(),
                    uid: uid,
                    mealLabel: effectiveLabel,
                    dateStr: effectiveDate,
                  );
                },
                icon: Icon(Icons.edit, color: colorScheme.primary),
                label: Text(
                  'Manualmente',
                  style: TextStyle(color: colorScheme.primary),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

/// Rilancia l'analisi IA per una foto già pendente (es. errore di rete).
Future<void> retryPendingMealAnalysis(
  BuildContext context,
  WidgetRef ref,
  PendingMealAnalysis pending,
) async {
  final uid = await ensureNutritionUid(context, ref);
  if (uid == null || !context.mounted) return;
  if (!await ensureActiveAiBackendHasKey(context, ref)) return;
  if (!context.mounted) return;

  ref.read(pendingMealAnalysisProvider.notifier).setRetrying(pending.id);

  try {
    final ai = ref.read(unifiedAiServiceProvider);
    final Map<String, dynamic> result;
    if (pending.isManualEntry) {
      result = await ai.getFoodInfoFromText(pending.manualDescription!);
    } else {
      result = await ai.analyzeNutritionFromImage(
        pending.imageBytes!,
        mimeType: pending.mimeType ?? 'image/jpeg',
      );
    }

    if (result.containsKey('error')) {
      ref
          .read(pendingMealAnalysisProvider.notifier)
          .finishWithError(pending.id, result['error']?.toString() ?? 'Errore');
      return;
    }

    ref.read(pendingMealAnalysisProvider.notifier).remove(pending.id);
    _pushNutritionMealReviewFromRoot(
      ref,
      result,
      uid: uid,
      mealLabel: pending.mealLabelKey,
      dateStr: pending.dateStr,
      mealPhotoBytes: pending.imageBytes,
    );
  } catch (e) {
    ref
        .read(pendingMealAnalysisProvider.notifier)
        .finishWithError(pending.id, e.toString());
  }
}

/// Assicura un uid valido (firma anonima se necessario).
Future<String?> ensureNutritionUid(BuildContext context, WidgetRef ref) async {
  var uid = ref.read(currentUidProvider);
  if (uid == null) {
    try {
      await ref.read(authNotifierProvider.notifier).signInAnonymously();
      uid = ref.read(currentUidProvider);
    } catch (e) {
      if (context.mounted) {
        showErrorDialog(context, 'Impossibile autenticarsi. Riprova. ($e)');
      }
      return null;
    }
    if (uid == null && context.mounted) {
      showErrorDialog(context, 'Utente non autenticato.');
      return null;
    }
  }
  return uid;
}

/// Dopo salvataggio/eliminazione pasto: aggiorna grafici e pacchetto Home
/// (calorie oggi).
void refreshNutritionAfterMealChange(WidgetRef ref) {
  ref.invalidate(nutritionChartDataProvider);
  ref.invalidate(nutritionDiaryWeekChartDataProvider);
  ref.invalidate(longevityHomePackageProvider);
}

/// Apre la schermata di revisione/modifica dell'analisi pasto (after manual
/// entry o dopo una modifica di un pasto esistente).
void showNutritionMealEditScreen(
  BuildContext context,
  WidgetRef ref,
  Map<String, dynamic> nut, {
  required String uid,
  String? mealLabel,
  String? dateStr,
  String? existingMealId,
  Future<void> Function()? onDelete,
}) {
  _showNutritionDialog(
    context,
    ref,
    nut,
    uid: uid,
    mealLabel: mealLabel,
    dateStr: dateStr,
    existingMealId: existingMealId,
    onDelete: onDelete,
  );
}

// ====================== INTERNAL ======================

bool get _isCameraSupported =>
    kIsWeb ||
    defaultTargetPlatform == TargetPlatform.iOS ||
    defaultTargetPlatform == TargetPlatform.android;

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

/// Analizza un pasto da fotocamera o galleria e apre la schermata di revisione
/// (salvataggio dopo conferma utente).
/// IMPORTANTE: `ImagePicker().pickImage` deve essere chiamato come PRIMA
/// operazione (no await prima) per non perdere il "user gesture token" su
/// web/PWA (iOS Chrome/Safari, Android Chrome) che bloccano silenziosamente
/// `<input>.click()` dopo qualsiasi gap asincrono.
Future<void> _analyzeMealFromPicker(
  BuildContext context,
  WidgetRef ref, {
  required String mealLabel,
  required String dateStr,
  required ImageSource imageSource,
}) async {
  final source = _isCameraSupported ? imageSource : ImageSource.gallery;
  final pickerFuture = ImagePicker().pickImage(
    source: source,
    maxWidth: 1280,
    maxHeight: 1280,
    imageQuality: 72,
  );

  final uid = await ensureNutritionUid(context, ref);
  if (uid == null) return;
  if (!context.mounted) return;

  if (!await ensureActiveAiBackendHasKey(context, ref)) {
    return;
  }
  if (!context.mounted) return;

  final xFile = await pickerFuture;
  if (xFile == null || !context.mounted) return;

  final bytes = await xFile.readAsBytes();
  final mimeType = mimeTypeForPickedImage(xFile);

  if (!context.mounted) return;

  final typeLabel = MealConstants.toMealType(mealLabel);
  final pendingId = ref
      .read(pendingMealAnalysisProvider.notifier)
      .startAnalysis(
        dateStr: dateStr,
        mealTypeLabel: typeLabel,
        mealLabelKey: mealLabel,
        imageBytes: Uint8List.fromList(bytes),
        mimeType: mimeType,
      );

  try {
    final ai = ref.read(unifiedAiServiceProvider);
    final result = await ai.analyzeNutritionFromImage(
      Uint8List.fromList(bytes),
      mimeType: mimeType,
    );

    if (result.containsKey('error')) {
      ref
          .read(pendingMealAnalysisProvider.notifier)
          .finishWithError(pendingId, result['error']?.toString() ?? 'Errore');
      return;
    }

    ref.read(pendingMealAnalysisProvider.notifier).remove(pendingId);
    _pushNutritionMealReviewFromRoot(
      ref,
      result,
      uid: uid,
      mealLabel: mealLabel,
      dateStr: dateStr,
      mealPhotoBytes: Uint8List.fromList(bytes),
    );
  } catch (e) {
    ref
        .read(pendingMealAnalysisProvider.notifier)
        .finishWithError(pendingId, e.toString());
  }
}

/// Analizza un pasto da descrizione testuale in background (come la foto).
Future<void> _analyzeMealFromManualText(
  WidgetRef ref, {
  required String text,
  required String uid,
  required String mealLabel,
  required String dateStr,
}) async {
  final typeLabel = MealConstants.toMealType(mealLabel);
  final pendingId = ref
      .read(pendingMealAnalysisProvider.notifier)
      .startManualAnalysis(
        dateStr: dateStr,
        mealTypeLabel: typeLabel,
        mealLabelKey: mealLabel,
        description: text,
      );

  try {
    final ai = ref.read(unifiedAiServiceProvider);
    final result = await ai.getFoodInfoFromText(text);

    if (result.containsKey('error')) {
      ref
          .read(pendingMealAnalysisProvider.notifier)
          .finishWithError(pendingId, result['error']?.toString() ?? 'Errore');
      return;
    }

    ref.read(pendingMealAnalysisProvider.notifier).remove(pendingId);
    _pushNutritionMealReviewFromRoot(
      ref,
      result,
      uid: uid,
      mealLabel: mealLabel,
      dateStr: dateStr,
    );
  } catch (e) {
    ref
        .read(pendingMealAnalysisProvider.notifier)
        .finishWithError(pendingId, e.toString());
  }
}

/// Apre [NutritionMealAnalysisScreen] sul navigator root (sopra tab shell).
void _pushNutritionMealReviewFromRoot(
  WidgetRef ref,
  Map<String, dynamic> nut, {
  required String uid,
  String? mealLabel,
  String? dateStr,
  String? existingMealId,
  Uint8List? mealPhotoBytes,
  Future<void> Function()? onDelete,
}) {
  final nav = rootNavigatorKey.currentState;
  final advice = nutritionAdviceString(nut['advice']);
  final foods = nutritionFoodsList(nut['foods']);

  if (nav == null) {
    scaffoldMessengerKey.currentState?.showSnackBar(
      const SnackBar(
        content: Text('Impossibile aprire la revisione pasto. Riprova.'),
        duration: Duration(seconds: 4),
      ),
    );
    return;
  }

  ref.read(nutritionMealEditProvider.notifier).beginFrom(nut);

  nav
      .push<void>(
        MaterialPageRoute<void>(
          builder: (ctx) => NutritionMealAnalysisScreen(
            advice: advice,
            foods: foods,
            onSave: (modifiedNut) async {
              try {
                await ref
                    .read(nutritionServiceProvider)
                    .saveToFirestore(
                      uid,
                      modifiedNut,
                      mealLabel: mealLabel,
                      date: dateStr != null ? DateTime.parse(dateStr) : null,
                      existingMealId: existingMealId,
                      mealPhotoBytes: mealPhotoBytes,
                    );
                refreshNutritionAfterMealChange(ref);
                scaffoldMessengerKey.currentState?.showSnackBar(
                  SnackBar(
                    content: Text(
                      existingMealId != null
                          ? 'Pasto aggiornato'
                          : 'Analisi salvata',
                    ),
                  ),
                );
              } catch (e) {
                if (ctx.mounted) showErrorDialog(ctx, e.toString());
              }
            },
            onDelete: onDelete,
          ),
        ),
      )
      .then((_) {
        ref.read(nutritionMealEditProvider.notifier).clear();
      });
}

void _showNutritionDialog(
  BuildContext context,
  WidgetRef ref,
  Map<String, dynamic> nut, {
  required String uid,
  String? mealLabel,
  String? dateStr,
  String? existingMealId,
  Future<void> Function()? onDelete,
}) {
  final advice = nutritionAdviceString(nut['advice']);
  final foods = nutritionFoodsList(nut['foods']);

  ref.read(nutritionMealEditProvider.notifier).beginFrom(nut);

  Navigator.of(context)
      .push<void>(
        MaterialPageRoute<void>(
          builder: (ctx) => NutritionMealAnalysisScreen(
            advice: advice,
            foods: foods,
            onSave: (modifiedNut) async {
              try {
                await ref
                    .read(nutritionServiceProvider)
                    .saveToFirestore(
                      uid,
                      modifiedNut,
                      mealLabel: mealLabel,
                      date: dateStr != null ? DateTime.parse(dateStr) : null,
                      existingMealId: existingMealId,
                    );
                refreshNutritionAfterMealChange(ref);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        existingMealId != null
                            ? 'Pasto aggiornato'
                            : 'Analisi salvata',
                      ),
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) showErrorDialog(context, e.toString());
              }
            },
            onDelete: onDelete,
          ),
        ),
      )
      .then((_) {
        ref.read(nutritionMealEditProvider.notifier).clear();
      });
}
