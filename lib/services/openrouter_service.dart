import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import 'ai_backend_preference_service.dart';
import 'nutrition_ai_json_parser.dart';

final openRouterServiceProvider = Provider<OpenRouterService>((ref) {
  return OpenRouterService(ref.watch(aiBackendPreferenceServiceProvider));
});


/// Servizio OpenRouter con supporto multi-modello e fallback automatico
class OpenRouterService {
  OpenRouterService(this._prefs);

  static const _baseUrl = 'https://openrouter.ai/api/v1/chat/completions';

  /// Header richiesti da OpenRouter per l'attribuzione
  static const _httpReferer = 'https://fitai-analyzer.app';
  static const _appTitle = 'FitAI Analyzer';

  final AiBackendPreferenceService _prefs;

  /// ================== MODELLI CON FALLBACK (aggiornato aprile 2026) ==================
  /// Ordine di priorità: migliori free + vision per analisi foto cibo + piani nutrizionali
  static const List<String> _modelFallbackChain = [
    'google/gemma-4-31b-it:free',           // Migliore qualità tra i free (se disponibile)
    'google/gemma-4-26b-a4b-it:free',       // Alternativa stabile Gemma 4
    'qwen/qwen2.5-vl-72b-instruct:free',    // Ottimo su visione (foto cibo)
    'llama-3.2-90b-vision-instruct:free',   // Buona visione (se disponibile free)
    'openrouter/free',                      // Router automatico OpenRouter sui modelli free
  ];

  /// Provider preferiti (prova prima questi, poi fallback)
  static const List<String> _preferredProviders = [
    'Google',
    'Qwen',
    'Together',
    'Fireworks',
    'DeepInfra',
  ];

  Future<String> _apiKey() async {
    final key = await _prefs.getOpenRouterKey();
    _checkApiKey(key);
    return key;
  }

  void _checkApiKey(String key) {
    if (key.isEmpty || key.startsWith('INSERISCI_QUI')) {
      throw StateError(
        'Configura la chiave OpenRouter nelle impostazioni o in .env',
      );
    }
  }

  Map<String, String> _headers(String key) => {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $key',
        'HTTP-Referer': _httpReferer,
        'X-Title': _appTitle,
      };

  /// Retry con backoff esponenziale per rate-limit e errori temporanei
  Future<T> _withRetry<T>(
    Future<T> Function() fn, {
    int maxAttempts = 5,
  }) async {
    int attempt = 0;
    while (true) {
      try {
        return await fn();
      } catch (e) {
        attempt++;
        final errorStr = e.toString().toLowerCase();

        final isRateLimit = errorStr.contains('429') ||
            errorStr.contains('rate') ||
            errorStr.contains('temporarily rate-limited');

        if (!isRateLimit && attempt >= maxAttempts) {
          rethrow;
        }

        final delaySeconds = (1 << (attempt - 1)).clamp(1, 8); // 1, 2, 4, 8...
        await Future.delayed(Duration(seconds: delaySeconds));
      }
    }
  }

  /// Metodo privato che esegue la chiamata con fallback modelli
  Future<String> _chat(
    List<Map<String, dynamic>> messages, {
    bool jsonObjectMode = false,
    Map<String, dynamic>? extraOptions,
  }) async {
    final key = await _apiKey();

    for (final model in _modelFallbackChain) {
      try {
        final body = <String, dynamic>{
          'model': model,
          'messages': messages,
          'stream': false,
          if (jsonObjectMode) 'response_format': {'type': 'json_object'},
        };

        // Aggiungi routing provider + extra options
        final extraBody = <String, dynamic>{
          'provider': {
            'order': _preferredProviders,
            'allow_fallbacks': true,
          },
          if (extraOptions != null) ...extraOptions,
        };

        final resp = await http.post(
          Uri.parse(_baseUrl),
          headers: _headers(key),
          body: jsonEncode({
            ...body,
            'extra_body': extraBody,
          }),
        );

        if (resp.statusCode == 429) {
          // Rate limit specifico del modello → prova il prossimo
          continue;
        }

        if (resp.statusCode < 200 || resp.statusCode >= 300) {
          throw StateError('OpenRouter (${resp.statusCode}): ${resp.body}');
        }

        final decoded = jsonDecode(resp.body) as Map<String, dynamic>?;
        final choices = decoded?['choices'] as List<dynamic>?;
        if (choices == null || choices.isEmpty) {
          throw StateError('Risposta senza choices');
        }

        final content = choices.first['message']?['content']?.toString();
        if (content == null || content.isEmpty) {
          throw StateError('Nessun contenuto nella risposta');
        }

        return content;
      } catch (e) {
        // Se è l'ultimo modello, rilancia l'errore
        if (model == _modelFallbackChain.last) {
          rethrow;
        }
        // Altrimenti prova il prossimo modello
        continue;
      }
    }

    throw StateError('Tutti i modelli OpenRouter hanno fallito');
  }

  // ====================== METODI PUBBLICI ======================

  Future<String> generateFromPrompt(String prompt) async {
    return _withRetry(() => _chat([
          {'role': 'user', 'content': prompt},
        ]));
  }

  Future<String> analyzeFitnessContext(String context) async {
    final prompt = '''
$context

---
Sulla base del contesto sopra, fornisci:
1. Analisi scientifica personalizzata del profilo fitness
2. Piano settimanale concreto (allenamenti, Zone 2, nutrizione)
3. Raccomandazioni basate su Peter Attia (Outlive) e longevità

Rispondi in italiano, strutturato e actionable.
''';

    return _withRetry(() => _chat([
          {'role': 'user', 'content': prompt},
        ]));
  }

  Future<Map<String, dynamic>> getFoodInfoFromText(String description) async {
    final prompt = """
Analizza questo pasto: "$description". Sei un nutrizionista esperto.
Restituisci SOLO un JSON valido con questo schema esatto:
{
  "dish_name": "...",
  "total_calories": numero,
  "protein_g": numero,
  "carbs_g": numero,
  "fat_g": numero,
  "fiber_g": numero,
  "sugar_g": numero,
  "longevity_score": numero (1-10),
  "foods": [{"name": "...", "calories": numero, "portion": "..."}],
  "advice": "consiglio breve in italiano"
}
""";

    try {
      final text = await _withRetry(() => _chat(
            [{'role': 'user', 'content': prompt}],
            jsonObjectMode: true,
          ));
      return parseNutritionAiJson(text);
    } catch (e) {
      return {'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> generateNutritionMealPlanJson(String prompt) async {
    try {
      final text = await _withRetry(() => _chat(
            [{'role': 'user', 'content': prompt}],
            jsonObjectMode: true,
          ));
      final map = parseNutritionAiJson(text);
      return map.containsKey('error') ? {'error': map['error']} : map;
    } catch (e) {
      return {'error': e.toString()};
    }
  }

  /// Analisi foto con fallback automatico su modelli vision
  Future<Map<String, dynamic>> analyzeNutritionFromImage(
    Uint8List imageBytes, {
    String mimeType = 'image/jpeg',
  }) async {
    final b64 = base64Encode(imageBytes);
    final dataUrl = 'data:$mimeType;base64,$b64';

    const prompt = '''
Analizza questa foto di cibo. Sei un nutrizionista esperto orientato alla longevità (stile Peter Attia).

Restituisci **SOLO** un JSON valido con questo schema esatto:
{
  "dish_name": "descrizione breve",
  "total_calories": numero,
  "protein_g": numero,
  "carbs_g": numero,
  "fat_g": numero,
  "fiber_g": numero,
  "sugar_g": numero,
  "longevity_score": numero (1-10),
  "foods": [{"name": "...", "calories": numero, "portion": "..."}],
  "advice": "consiglio breve in italiano"
}

Stima realistica quantità e macronutrienti dal contenuto visibile.
''';

    try {
      final text = await _withRetry(() => _chat(
            [
              {
                'role': 'user',
                'content': [
                  {'type': 'text', 'text': prompt},
                  {
                    'type': 'image_url',
                    'image_url': {'url': dataUrl},
                  },
                ],
              },
            ],
            jsonObjectMode: true,
          ));

      return parseNutritionAiJson(text);
    } catch (e) {
      return {
        'error': 'Analisi foto fallita: ${e.toString()}. '
            'Prova più tardi o cambia modello nelle impostazioni.'
      };
    }
  }
}