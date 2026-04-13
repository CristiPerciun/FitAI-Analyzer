import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kDebugMode, kIsWeb, debugPrint;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import 'ai_backend_preference_service.dart';
import 'nutrition_ai_json_parser.dart';

final openRouterServiceProvider = Provider<OpenRouterService>((ref) {
  return OpenRouterService(ref.watch(aiBackendPreferenceServiceProvider));
});

/// Dati da [GET /api/v1/key](https://openrouter.ai/docs/api/api-reference/api-keys/get-current-key)
class OpenRouterKeyCredits {
  const OpenRouterKeyCredits({
    this.label,
    this.limitUsd,
    this.limitRemainingUsd,
    this.usageUsd,
    this.isFreeTier,
  });

  final String? label;
  final double? limitUsd;
  final double? limitRemainingUsd;
  final double? usageUsd;
  final bool? isFreeTier;
}

class OpenRouterKeyCreditsResult {
  const OpenRouterKeyCreditsResult._(this.data, this.errorMessage);

  const OpenRouterKeyCreditsResult.success(OpenRouterKeyCredits data)
      : this._(data, null);

  const OpenRouterKeyCreditsResult.failure(String message)
      : this._(null, message);

  final OpenRouterKeyCredits? data;
  final String? errorMessage;

  bool get isSuccess => data != null;
}

/// Servizio OpenRouter con supporto multi-modello e fallback automatico
class OpenRouterService {
  OpenRouterService(this._prefs);

  static const _baseUrl = 'https://openrouter.ai/api/v1/chat/completions';
  static const _keyInfoUrl = 'https://openrouter.ai/api/v1/key';

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
      _orLog('API key mancante o placeholder');
      throw StateError(
        'Configura la chiave OpenRouter nelle impostazioni o in .env',
      );
    }
  }

  static void _orLog(String message) {
    if (kDebugMode) {
      debugPrint('[OpenRouter] $message');
    }
  }

  static String _bodySnippet(String body, {int maxLen = 800}) {
    final t = body.trim();
    if (t.length <= maxLen) return t;
    return '${t.substring(0, maxLen)}…';
  }

  double? _numToDouble(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString());
  }

  /// Saldo crediti (USD) associato alla chiave corrente.
  Future<OpenRouterKeyCreditsResult> fetchKeyCredits() async {
    final key = await _prefs.getOpenRouterKey();
    if (key.isEmpty || key.startsWith('INSERISCI_QUI')) {
      return const OpenRouterKeyCreditsResult.failure(
        'Chiave OpenRouter non configurata.',
      );
    }

    try {
      _orLog('GET /api/v1/key …');
      final resp = await http
          .get(
            Uri.parse(_keyInfoUrl),
            headers: _headers(key),
          )
          .timeout(const Duration(seconds: 25));

      if (resp.statusCode != 200) {
        _orLog('/key → ${resp.statusCode} ${_bodySnippet(resp.body)}');
        return OpenRouterKeyCreditsResult.failure(
          'Errore ${resp.statusCode}: ${resp.body}',
        );
      }
      _orLog('/key → 200 OK');

      final decoded = jsonDecode(resp.body);
      if (decoded is! Map<String, dynamic>) {
        return const OpenRouterKeyCreditsResult.failure(
          'Risposta API non valida.',
        );
      }

      final data = decoded['data'];
      if (data is! Map<String, dynamic>) {
        return const OpenRouterKeyCreditsResult.failure(
          'Risposta API senza campo data.',
        );
      }

      return OpenRouterKeyCreditsResult.success(
        OpenRouterKeyCredits(
          label: data['label']?.toString(),
          limitUsd: _numToDouble(data['limit']),
          limitRemainingUsd: _numToDouble(data['limit_remaining']),
          usageUsd: _numToDouble(data['usage']),
          isFreeTier: data['is_free_tier'] as bool?,
        ),
      );
    } on TimeoutException {
      return const OpenRouterKeyCreditsResult.failure(
        'Timeout (25s) verso OpenRouter.',
      );
    } catch (e, st) {
      _orLog('fetchKeyCredits error: $e');
      if (kDebugMode) {
        debugPrint(st.toString());
      }
      final webHint = kIsWeb
          ? ' Su Chrome/Web le chiamate dirette possono essere bloccate da CORS: '
              'prova la stessa funzione su Android/iOS, oppure serve un proxy lato server.'
          : '';
      return OpenRouterKeyCreditsResult.failure(
        'Connessione fallita: $e$webHint',
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
        _orLog(
          '_withRetry attempt $attempt/$maxAttempts after: $e → wait ${delaySeconds}s',
        );
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
    _orLog(
      'chat/completions: ${messages.length} msg, jsonObject=$jsonObjectMode, '
      'web=$kIsWeb',
    );

    Object? lastFailure;

    for (final model in _modelFallbackChain) {
      try {
        _orLog('→ modello: $model');
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
          lastFailure =
              '429 rate limit su "$model" (tutti i modelli in coda hanno risposto 429?)';
          _orLog('← HTTP 429, provo modello successivo');
          continue;
        }

        if (resp.statusCode < 200 || resp.statusCode >= 300) {
          final snippet = _bodySnippet(resp.body);
          _orLog('← HTTP ${resp.statusCode}: $snippet');
          lastFailure = 'HTTP ${resp.statusCode}: $snippet';
          throw StateError('OpenRouter (${resp.statusCode}): ${resp.body}');
        }

        final decoded = jsonDecode(resp.body);
        if (decoded is! Map<String, dynamic>) {
          final snippet = _bodySnippet(resp.body);
          _orLog('← JSON root non è un oggetto: $snippet');
          lastFailure = 'Risposta JSON inattesa (non oggetto)';
          throw StateError('OpenRouter: risposta non è un JSON oggetto');
        }

        final choices = decoded['choices'] as List<dynamic>?;
        if (choices == null || choices.isEmpty) {
          _orLog('← nessuna choice in risposta: ${_bodySnippet(resp.body)}');
          lastFailure = 'choices vuote o assenti';
          throw StateError('Risposta senza choices');
        }

        final content = choices.first['message']?['content']?.toString();
        if (content == null || content.isEmpty) {
          _orLog('← message.content vuoto');
          lastFailure = 'content vuoto';
          throw StateError('Nessun contenuto nella risposta');
        }

        _orLog('← OK con $model (${content.length} caratteri)');
        return content;
      } catch (e, st) {
        lastFailure = e;
        _orLog('modello "$model" fallito: $e');
        if (kDebugMode) {
          debugPrint(st.toString());
        }
        if (model == _modelFallbackChain.last) {
          rethrow;
        }
        continue;
      }
    }

    final suffix = lastFailure != null ? ' — ultimo: $lastFailure' : '';
    _orLog('nessun modello ha risposto con successo$suffix');
    throw StateError('Tutti i modelli OpenRouter hanno fallito$suffix');
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
  "estimated_portion_grams": numero (grammi totali del piatto usati per la stima),
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
  "estimated_portion_grams": numero (grammi totali del piatto usati per la stima),
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