import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'ai_backend_preference_service.dart';
import 'deepseek_service.dart';
import 'gemini_service.dart';
import 'openrouter_service.dart';

/// Instrada le chiamate IA verso il backend selezionato in [AiBackendPreferenceService].
final unifiedAiServiceProvider = Provider<UnifiedAiService>((ref) {
  return UnifiedAiService(
    backendPrefs: ref.watch(aiBackendPreferenceServiceProvider),
    gemini: ref.watch(geminiServiceProvider),
    deepseek: ref.watch(deepSeekServiceProvider),
    openrouter: ref.watch(openRouterServiceProvider),
  );
});

class UnifiedAiService {
  UnifiedAiService({
    required AiBackendPreferenceService backendPrefs,
    required GeminiService gemini,
    required DeepSeekService deepseek,
    required OpenRouterService openrouter,
  })  : _backendPrefs = backendPrefs,
        _gemini = gemini,
        _deepseek = deepseek,
        _openrouter = openrouter;

  final AiBackendPreferenceService _backendPrefs;
  final GeminiService _gemini;
  final DeepSeekService _deepseek;
  final OpenRouterService _openrouter;

  Future<AiBackend> _backend() => _backendPrefs.getBackend();

  Future<String> generateFromPrompt(String prompt) async {
    final b = await _backend();
    return switch (b) {
      AiBackend.deepseek => _deepseek.generateFromPrompt(prompt),
      AiBackend.openrouter => _openrouter.generateFromPrompt(prompt),
      AiBackend.gemini => _gemini.generateFromPrompt(prompt),
    };
  }

  Future<String> analyzeFitnessContext(String context) async {
    final b = await _backend();
    return switch (b) {
      AiBackend.deepseek => _deepseek.analyzeFitnessContext(context),
      AiBackend.openrouter => _openrouter.analyzeFitnessContext(context),
      AiBackend.gemini => _gemini.analyzeFitnessContext(context),
    };
  }

  Future<Map<String, dynamic>> getFoodInfoFromText(String description) async {
    final b = await _backend();
    return switch (b) {
      AiBackend.deepseek => _deepseek.getFoodInfoFromText(description),
      AiBackend.openrouter => _openrouter.getFoodInfoFromText(description),
      AiBackend.gemini => _gemini.getFoodInfoFromText(description),
    };
  }

  Future<Map<String, dynamic>> analyzeNutritionFromImage(
    Uint8List imageBytes, {
    String mimeType = 'image/jpeg',
  }) async {
    final b = await _backend();
    return switch (b) {
      AiBackend.deepseek =>
        _deepseek.analyzeNutritionFromImage(imageBytes, mimeType: mimeType),
      AiBackend.openrouter =>
        _openrouter.analyzeNutritionFromImage(imageBytes, mimeType: mimeType),
      AiBackend.gemini =>
        _gemini.analyzeNutritionFromImage(imageBytes, mimeType: mimeType),
    };
  }

  Future<Map<String, dynamic>> generateNutritionMealPlanJson(
    String prompt,
  ) async {
    final b = await _backend();
    return switch (b) {
      AiBackend.deepseek => _deepseek.generateNutritionMealPlanJson(prompt),
      AiBackend.openrouter => _openrouter.generateNutritionMealPlanJson(prompt),
      AiBackend.gemini => _gemini.generateNutritionMealPlanJson(prompt),
    };
  }
}
