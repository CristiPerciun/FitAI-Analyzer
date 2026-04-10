import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fitai_analyzer/models/ai_current_allenamenti_model.dart';
import 'package:fitai_analyzer/models/home_longevity_plan_day.dart';
import 'package:fitai_analyzer/models/longevity_home_package.dart';
import 'package:fitai_analyzer/models/meal_model.dart';
import 'package:fitai_analyzer/models/nutrition_meal_plan_ai.dart';
import 'package:fitai_analyzer/services/unified_ai_service.dart';
import 'package:fitai_analyzer/utils/meal_constants.dart';
import 'package:fitai_analyzer/providers/auth_notifier.dart';
import 'package:fitai_analyzer/providers/garmin_sync_notifier.dart';
import 'package:fitai_analyzer/services/ai_backend_preference_service.dart';
import 'package:fitai_analyzer/services/ai_prompt_service.dart';
import 'package:fitai_analyzer/services/auth_service.dart';
import 'package:fitai_analyzer/services/deepseek_service.dart';
import 'package:fitai_analyzer/services/gemini_api_key_service.dart';
import 'package:fitai_analyzer/services/gemini_service.dart';
import 'package:fitai_analyzer/services/openrouter_service.dart';
import 'package:fitai_analyzer/services/longevity_engine.dart';
import 'package:fitai_analyzer/services/nutrition_meal_plan_service.dart';
import 'package:fitai_analyzer/services/nutrition_service.dart';
import 'package:fitai_analyzer/services/strava_service.dart';
import 'package:fitai_analyzer/ui/home/widgets/pillar_grid.dart';
import 'package:fitai_analyzer/utils/platform_firestore_fix.dart';
import 'package:fitai_analyzer/utils/prompt_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

export 'package:fitai_analyzer/services/unified_ai_service.dart'
    show UnifiedAiService, unifiedAiServiceProvider;

/// Service providers - dependency injection via Riverpod
final authServiceProvider = Provider<AuthService>((ref) => AuthService());

/// Stato backend IA (Gemini / DeepSeek / OpenRouter) per Impostazioni e gating.
final aiBackendSettingsProvider =
    FutureProvider.autoDispose<AiBackendSettingsSnapshot>((ref) async {
  final prefs = ref.watch(aiBackendPreferenceServiceProvider);
  final gemini = ref.watch(geminiApiKeyServiceProvider);
  return AiBackendSettingsSnapshot(
    backend: await prefs.getBackend(),
    hasGeminiKey: await gemini.hasValidKey(),
    hasDeepSeekKey: await prefs.hasValidDeepSeekKey(),
    hasOpenRouterKey: await prefs.hasValidOpenRouterKey(),
  );
});

/// Invalida routing IA dopo cambio chiave o backend.
/// Accetta `WidgetRef` (UI) o il `ref` di un `Notifier`: in Riverpod 2.x non c’è un supertipo comune.
void invalidateAiRouting(dynamic ref) {
  ref.invalidate(aiBackendSettingsProvider);
  ref.invalidate(unifiedAiServiceProvider);
  ref.invalidate(geminiServiceProvider);
  ref.invalidate(deepSeekServiceProvider);
  ref.invalidate(openRouterServiceProvider);
}

/// Generazione piano alimentare JSON (pagina Alimentazione).
final nutritionMealPlanServiceProvider = Provider<NutritionMealPlanService>((ref) {
  return NutritionMealPlanService(
    FirebaseFirestore.instance,
    ref.read(unifiedAiServiceProvider),
    ref.read(aiPromptServiceProvider),
  );
});

/// Piano AI pasti + obiettivi per colazione/pranzo/cena (`ai_current/meal`).
final nutritionMealPlanAiStreamProvider =
    StreamProvider.autoDispose<NutritionMealPlanAi?>((ref) async* {
  final uid = ref.watch(authNotifierProvider).user?.uid;
  if (uid == null) {
    yield null;
    return;
  }
  final docRef = FirebaseFirestore.instance
      .collection('users')
      .doc(uid)
      .collection('ai_current')
      .doc('meal');
  await for (final snap in documentSnapshotStream(docRef)) {
    if (!snap.exists || snap.data() == null) {
      yield null;
    } else {
      yield NutritionMealPlanAi.fromFirestore(snap.data()!);
    }
  }
});

final nutritionMealPlanGeneratingProvider = StateProvider<bool>((ref) => false);

/// Stato connessione Strava. Invalidare dopo connect/disconnect.
final stravaConnectedProvider = FutureProvider.autoDispose<bool>((ref) async {
  return ref.read(stravaServiceProvider).isConnected();
});

/// Indice tab attivo nella bottom bar (0=Home, 1=Allenamenti, 2=Alimentazione, 3=Impostazioni).
final selectedTabIndexProvider = StateProvider<int>((ref) => 0);

/// Pacchetto informativo unificato per la Home (Livello 1+2+3).
/// Usato per popolare la Home con dati AI: oggi, rolling 10 giorni, baseline annuale.
final longevityHomePackageProvider =
    FutureProvider.autoDispose<LongevityHomePackage>((ref) async {
  ref.keepAlive();
  final uid = ref.watch(authNotifierProvider).user?.uid;
  if (uid == null) return const LongevityHomePackage();
  return ref.read(longevityEngineProvider).buildHomePackage(uid);
});

/// Piano Home (prompt unificato): `ai_current/home_longevity_plan`.
final homeLongevityPlanDayStreamProvider =
    StreamProvider.autoDispose<HomeLongevityPlanDay?>((ref) async* {
  final uid = ref.watch(authNotifierProvider).user?.uid;
  if (uid == null) {
    yield null;
    return;
  }
  final docRef = FirebaseFirestore.instance
      .collection('users')
      .doc(uid)
      .collection('ai_current')
      .doc('home_longevity_plan');
  await for (final snap in documentSnapshotStream(docRef)) {
    final today = localCalendarDateKey();
    if (!snap.exists || snap.data() == null) {
      yield null;
      continue;
    }
    final plan = HomeLongevityPlanDay.fromFirestore(snap.data()!);
    yield plan.forDate == today ? plan : null;
  }
});

/// Obiettivo allenamento giornaliero AI (`ai_current/allenamenti`).
final aiCurrentAllenamentiStreamProvider =
    StreamProvider.autoDispose<AiCurrentAllenamentiModel?>((ref) async* {
  final uid = ref.watch(authNotifierProvider).user?.uid;
  if (uid == null) {
    yield null;
    return;
  }
  final docRef = FirebaseFirestore.instance
      .collection('users')
      .doc(uid)
      .collection('ai_current')
      .doc('allenamenti');
  await for (final snap in documentSnapshotStream(docRef)) {
    final today = localCalendarDateKey();
    if (!snap.exists || snap.data() == null) {
      yield null;
      continue;
    }
    final model = AiCurrentAllenamentiModel.fromFirestore(snap.data()!);
    yield model.forDate == today ? model : null;
  }
});

/// Dopo una generazione Gemini, aggiorna subito la UI (su Windows lo stream può ritardare).
class HomeLongevityPlanOptimistic extends AutoDisposeNotifier<HomeLongevityPlanDay?> {
  @override
  HomeLongevityPlanDay? build() {
    ref.listen<String?>(
      authNotifierProvider.select((a) => a.user?.uid),
      (prev, next) {
        if (prev != null && prev != next) {
          state = null;
        }
      },
    );
    return null;
  }

  void setPlan(HomeLongevityPlanDay? p) => state = p;
}

final homeLongevityPlanOptimisticProvider =
    AutoDisposeNotifierProvider<HomeLongevityPlanOptimistic, HomeLongevityPlanDay?>(
        HomeLongevityPlanOptimistic.new);

/// Piano da mostrare in Home: stream giornaliero + override locale post-generazione.
final homeLongevityPlanForUiProvider = Provider<HomeLongevityPlanDay?>((ref) {
  final today = localCalendarDateKey();
  final optimistic = ref.watch(homeLongevityPlanOptimisticProvider);
  final asyncSnap = ref.watch(homeLongevityPlanDayStreamProvider);
  final fromStream = asyncSnap.asData?.value;

  final optOk = optimistic != null && optimistic.forDate == today;
  final streamOk = fromStream != null && fromStream.forDate == today;
  if (streamOk) return fromStream;
  if (optOk) return optimistic;
  return null;
});

Map<LongevityPillar, String> _pillarMapFromPlan(HomeLongevityPlanDay? plan) {
  if (plan == null) return {};
  final m = <LongevityPillar, String>{};
  for (final p in LongevityPillar.values) {
    final v = plan.pillars[p.name];
    if (v != null && v.isNotEmpty) m[p] = v;
  }
  return m;
}

/// Esportato per la Home: mappa pilastri da [homeLongevityPlanForUiProvider].
final homeDailyGoalsMapProvider = Provider<Map<LongevityPillar, String>>((ref) {
  return _pillarMapFromPlan(ref.watch(homeLongevityPlanForUiProvider));
});

/// Genera e salva il piano giornaliero unificato via prompt Gemini.
/// Legge: profile + aggregazione ieri + rolling_10days + diario.
/// Salva: ai_current/meal, ai_current/allenamenti, ai_current/home_longevity_plan, profile/diary.
Future<void> loadLongevityPlan(WidgetRef ref) async {
  final uid = ref.read(authNotifierProvider).user?.uid;
  if (uid == null) return;

  final prefs = ref.read(aiBackendPreferenceServiceProvider);
  final geminiKeys = ref.read(geminiApiKeyServiceProvider);
  if (!await prefs.isActiveBackendConfigured(geminiKeys)) return;

  final engine = ref.read(longevityEngineProvider);
  final ctx = await engine.buildUnifiedDailyContext(uid);
  final prompt = engine.buildUnifiedPromptFromContext(ctx);
  await savePromptToFile(prompt);

  final response =
      await ref.read(unifiedAiServiceProvider).generateFromPrompt(prompt);

  final cleaned = response
      .replaceAll(RegExp(r'```json\s*'), '')
      .replaceAll(RegExp(r'\s*```'), '')
      .trim();
  try {
    final decoded = json.decode(cleaned) as Map<String, dynamic>?;
    if (decoded == null) return;

    final todayLocal = localCalendarDateKey();

    // Salva i 3 documenti ai_current + aggiorna diario
    await engine.saveUnifiedAiCurrent(uid, decoded, todayLocal);

    // Aggiorna subito lo stato ottimistico per la Home (evita attesa stream)
    final homePlan = HomeLongevityPlanDay.fromUnifiedJson(decoded, todayLocal);
    ref.read(homeLongevityPlanOptimisticProvider.notifier).setPlan(homePlan);
  } catch (_) {}
}

/// Date con pasti, ordinate dal più recente.
final mealDatesProvider = StreamProvider<List<String>>((ref) {
  final uid = ref.watch(authNotifierProvider).user?.uid;
  if (uid == null) return Stream.value([]);
  return ref.read(nutritionServiceProvider).mealDatesStream(uid);
});

/// Filtro data: null = Oggi, dateFilterAll = Tutti, altrimenti data.
final selectedMealDateFilterProvider = StateProvider<String?>((ref) => null);

/// Pasti per una data, raggruppati per tipo.
final mealsForDateByTypeProvider =
    StreamProvider.family<Map<String, List<MealModel>>, String>((ref, dateStr) async* {
  final uid = ref.watch(authNotifierProvider).user?.uid;
  if (uid == null) {
    yield {};
    return;
  }
  final nutrition = ref.read(nutritionServiceProvider);
  await for (final meals in nutrition.mealsForDayStream(uid, dateStr)) {
    yield _groupMealsByType(meals);
  }
});

/// Chiede al server aggiornamento attività/biometrici: Garmin (`sync-today`) o solo Strava (`delta`).
Future<void> refreshGarminSync(
  WidgetRef ref,
  String? uid, {
  String trigger = 'pull_to_refresh',
}) async {
  if (uid == null) return;
  await ref.read(garminSyncNotifierProvider.notifier).syncNow(
        uid: uid,
        trigger: trigger,
      );
}

Map<String, List<MealModel>> _groupMealsByType(List<MealModel> meals) {
  final byType = <String, List<MealModel>>{
    for (final t in MealConstants.mealTypes) t: [],
  };
  for (final m in meals) {
    final type = m.mealType.isNotEmpty ? m.mealType : MealConstants.inferMealType(m.dishName);
    if (byType.containsKey(type)) {
      byType[type]!.add(m);
    } else {
      byType['Pranzo']!.add(m);
    }
  }
  return byType;
}
