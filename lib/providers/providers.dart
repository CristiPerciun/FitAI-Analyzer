import 'dart:convert';

import 'package:fitai_analyzer/models/longevity_home_package.dart';
import 'package:fitai_analyzer/models/meal_model.dart';
import 'package:fitai_analyzer/providers/auth_notifier.dart';
import 'package:fitai_analyzer/services/auth_service.dart';
import 'package:fitai_analyzer/services/gemini_api_key_service.dart';
import 'package:fitai_analyzer/services/gemini_service.dart';
import 'package:fitai_analyzer/services/longevity_engine.dart';
import 'package:fitai_analyzer/services/nutrition_service.dart';
import 'package:fitai_analyzer/services/strava_service.dart';
import 'package:fitai_analyzer/ui/home/widgets/pillar_grid.dart';
import 'package:fitai_analyzer/utils/prompt_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Service providers - dependency injection via Riverpod
final authServiceProvider = Provider<AuthService>((ref) => AuthService());

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
  final uid = ref.watch(authNotifierProvider).user?.uid;
  if (uid == null) return const LongevityHomePackage();
  return ref.read(longevityEngineProvider).buildHomePackage(uid);
});

/// Obiettivi giornalieri dei 4 pilastri (da Gemini). Null = non ancora generati.
final dailyGoalsProvider =
    StateProvider<Map<LongevityPillar, String>?>((ref) => null);

/// Obiettivo settimanale "Weekly Sprint" (da Gemini). Null = non ancora generato.
final weeklySprintProvider = StateProvider<String?>((ref) => null);

/// Consiglio strategico a lungo termine (da Gemini). Per Sezione Visione.
final strategicAdviceProvider = StateProvider<String?>((ref) => null);

/// Carica il piano di longevità completo via prompt master.
/// Popola: 4 micro-obiettivi (odierno), macro settimanale, consiglio strategico (visione).
Future<void> loadLongevityPlan(WidgetRef ref) async {
  final uid = ref.read(authNotifierProvider).user?.uid;
  if (uid == null) return;

  final apiKey = ref.read(geminiApiKeyServiceProvider);
  if (!await apiKey.hasValidKey()) return;

  final prompt = await ref.read(longevityEngineProvider).buildLongevityPlanPrompt(uid);
  await savePromptToFile(prompt);
  final response = await ref.read(geminiServiceProvider).generateFromPrompt(prompt);

  final cleaned = response
      .replaceAll(RegExp(r'```json\s*'), '')
      .replaceAll(RegExp(r'\s*```'), '')
      .trim();
  try {
    final decoded = json.decode(cleaned) as Map<String, dynamic>?;
    if (decoded != null) {
      final map = <LongevityPillar, String>{};
      for (final p in LongevityPillar.values) {
        final key = p.name;
        final val = decoded[key]?.toString();
        if (val != null && val.isNotEmpty) map[p] = val;
      }
      if (map.isNotEmpty) ref.read(dailyGoalsProvider.notifier).state = map;

      final weekly = decoded['weekly_sprint']?.toString();
      if (weekly != null && weekly.isNotEmpty) {
        ref.read(weeklySprintProvider.notifier).state = weekly;
      }

      final strategic = decoded['strategic_advice']?.toString();
      if (strategic != null && strategic.isNotEmpty) {
        ref.read(strategicAdviceProvider.notifier).state = strategic;
      }
    }
  } catch (_) {}
}

/// Stream dei pasti di oggi, raggruppati per tipo (Colazione/Pranzo/Cena).
/// Ritorna mappa mealLabel -> List di MealModel.
final todayMealsByTypeProvider = StreamProvider<Map<String, List<MealModel>>>((ref) async* {
  final authState = ref.watch(authNotifierProvider);
  final uid = authState.user?.uid;
  if (uid == null) {
    yield {};
    return;
  }
  final dateStr = DateTime.now().toIso8601String().split('T')[0];
  final nutrition = ref.read(nutritionServiceProvider);
  await for (final meals in nutrition.mealsForDayStream(uid, dateStr)) {
    yield _groupMealsByType(meals);
  }
});

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

Map<String, List<MealModel>> _groupMealsByType(List<MealModel> meals) {
  final byType = <String, List<MealModel>>{
    'Colazione': [],
    'Pranzo': [],
    'Cena': [],
  };
  for (final m in meals) {
    final type = m.mealType.isNotEmpty ? m.mealType : _inferMealType(m);
    if (byType.containsKey(type)) {
      byType[type]!.add(m);
    } else {
      byType['Pranzo']!.add(m);
    }
  }
  return byType;
}

String _inferMealType(MealModel m) {
  final d = m.dishName.toLowerCase();
  if (d.startsWith('colazione')) return 'Colazione';
  if (d.startsWith('pranzo')) return 'Pranzo';
  if (d.startsWith('cena')) return 'Cena';
  return 'Pranzo';
}
