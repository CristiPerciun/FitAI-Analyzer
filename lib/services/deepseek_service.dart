import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import 'ai_backend_preference_service.dart';
import 'nutrition_ai_json_parser.dart';

final deepSeekServiceProvider = Provider<DeepSeekService>((ref) {
  return DeepSeekService(ref.watch(aiBackendPreferenceServiceProvider));
});

/// Client API DeepSeek (formato compatibile OpenAI).
/// Documentazione: https://api-docs.deepseek.com/
class DeepSeekService {
  DeepSeekService(this._prefs);

  static const _baseUrl = 'https://api.deepseek.com/chat/completions';
  static const _model = 'deepseek-chat';

  final AiBackendPreferenceService _prefs;

  Future<String> _apiKey() async {
    final key = await _prefs.getDeepSeekKey();
    _checkApiKey(key);
    return key;
  }

  void _checkApiKey(String key) {
    if (key.isEmpty || key.startsWith('INSERISCI_QUI')) {
      throw StateError(
        'Configura la chiave DeepSeek: Impostazioni → Chiave DeepSeek '
        'o variabile DEEPSEEK_API_KEY in .env (platform.deepseek.com/api_keys)',
      );
    }
  }

  Future<T> _withRetry<T>(
    Future<T> Function() fn, {
    int maxAttempts = 4,
  }) async {
    var attempt = 0;
    while (true) {
      try {
        return await fn();
      } catch (e) {
        attempt++;
        final s = e.toString();
        final isUnavailable = s.contains('503') ||
            s.contains('502') ||
            s.contains('429') ||
            s.contains('UNAVAILABLE') ||
            s.contains('high demand');
        if (!isUnavailable || attempt >= maxAttempts) rethrow;
        await Future<void>.delayed(Duration(seconds: 1 << attempt));
      }
    }
  }

  Future<String> _chat(
    List<Map<String, dynamic>> messages, {
    bool jsonObjectMode = false,
  }) async {
    final key = await _apiKey();
    final body = <String, dynamic>{
      'model': _model,
      'messages': messages,
      'stream': false,
    };
    if (jsonObjectMode) {
      body['response_format'] = {'type': 'json_object'};
    }

    final resp = await http.post(
      Uri.parse(_baseUrl),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $key',
      },
      body: jsonEncode(body),
    );

    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw StateError(
        'DeepSeek API (${resp.statusCode}): ${resp.body.length > 400 ? '${resp.body.substring(0, 400)}…' : resp.body}',
      );
    }

    final decoded = jsonDecode(resp.body) as Map<String, dynamic>?;
    final choices = decoded?['choices'] as List<dynamic>?;
    if (choices == null || choices.isEmpty) {
      throw StateError('DeepSeek: risposta senza choices');
    }
    final first = choices.first as Map<String, dynamic>?;
    final msg = first?['message'] as Map<String, dynamic>?;
    final text = msg?['content']?.toString();
    if (text == null || text.isEmpty) {
      throw StateError('DeepSeek non ha restituito testo');
    }
    return text;
  }

  Future<String> generateFromPrompt(String prompt) async {
    return _withRetry(() async {
      return _chat(
        [
          {'role': 'user', 'content': prompt},
        ],
      );
    });
  }

  Future<String> analyzeFitnessContext(String context) async {
    final prompt = '''
$context

---

Sulla base del contesto sopra, fornisci:
1. Analisi scientifica personalizzata del profilo fitness
2. Piano settimanale concreto (allenamenti, Zone 2, nutrizione)
3. Raccomandazioni basate su Peter Attia (Outlive) e longevità

Rispondi in italiano, in modo strutturato e actionable.
''';
    return _withRetry(() async {
      return _chat([
        {'role': 'user', 'content': prompt},
      ]);
    });
  }

  Future<Map<String, dynamic>> getFoodInfoFromText(String description) async {
    final prompt = """
Analizza questo pasto: "$description". Sei un nutrizionista esperto.
Restituisci un JSON con questo schema esatto (allineato all'analisi foto):
{
  "dish_name": "nome del piatto",
  "total_calories": numero,
  "protein_g": numero,
  "carbs_g": numero,
  "fat_g": numero,
  "fiber_g": numero,
  "sugar_g": numero,
  "longevity_score": numero da 1 a 10,
  "foods": [{"name": "stringa", "calories": numero, "portion": "stringa"}],
  "advice": "un breve consiglio nutrizionale in italiano"
}
Rispondi solo con il JSON, niente testo aggiuntivo.
""";

    try {
      final text = await _withRetry(() async {
        return _chat(
          [
            {'role': 'user', 'content': prompt},
          ],
          jsonObjectMode: true,
        );
      });
      return parseNutritionAiJson(text);
    } catch (e) {
      return {'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> generateNutritionMealPlanJson(
    String prompt,
  ) async {
    final text = await _withRetry(() async {
      return _chat(
        [
          {'role': 'user', 'content': prompt},
        ],
        jsonObjectMode: true,
      );
    });
    final map = parseNutritionAiJson(text);
    if (map.containsKey('error')) {
      return {'error': map['error']?.toString() ?? 'JSON non valido'};
    }
    return map;
  }

  /// Immagine in formato OpenAI multimodale (se l'endpoint la accetta).
  Future<Map<String, dynamic>> analyzeNutritionFromImage(
    Uint8List imageBytes, {
    String mimeType = 'image/jpeg',
  }) async {
    final b64 = base64Encode(imageBytes);
    final dataUrl = 'data:$mimeType;base64,$b64';

    const prompt = '''
Analizza questa foto di un piatto/cibo. Sei un nutrizionista orientato alla longevità (Peter Attia, Outlive).

Restituisci un JSON con questo schema esatto:
{
  "dish_name": "stringa breve descrittiva del piatto (es. Pollo e Broccoli)",
  "total_calories": numero,
  "protein_g": numero,
  "carbs_g": numero,
  "fat_g": numero,
  "fiber_g": numero,
  "sugar_g": numero,
  "longevity_score": numero da 1 a 10 (10 = ottimo per longevità: proteine adeguate, fibre, pochi zuccheri raffinati),
  "foods": [{"name": "stringa", "calories": numero, "portion": "stringa"}],
  "advice": "stringa con consigli nutrizionali brevi in italiano"
}

Stima le calorie e i macronutrienti in base al cibo visibile. Sii realistico.
''';

    final key = await _apiKey();
    final body = jsonEncode({
      'model': _model,
      'messages': [
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
      'stream': false,
      'response_format': {'type': 'json_object'},
    });

    final resp = await http.post(
      Uri.parse(_baseUrl),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $key',
      },
      body: body,
    );

    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      return {
        'error':
            'Analisi foto con DeepSeek non disponibile (${resp.statusCode}). '
            'L\'API ufficiale deepseek-chat è principalmente testuale: '
            'passa a Gemini in Impostazioni per le foto, oppure verifica aggiornamenti DeepSeek. '
            'Dettaglio: ${resp.body.length > 280 ? '${resp.body.substring(0, 280)}…' : resp.body}',
      };
    }

    final decoded = jsonDecode(resp.body) as Map<String, dynamic>?;
    final choices = decoded?['choices'] as List<dynamic>?;
    if (choices == null || choices.isEmpty) {
      return {'error': 'DeepSeek: risposta senza choices'};
    }
    final first = choices.first as Map<String, dynamic>?;
    final msg = first?['message'] as Map<String, dynamic>?;
    final text = msg?['content']?.toString();
    if (text == null || text.isEmpty) {
      return {'error': 'DeepSeek non ha restituito risposta per la foto'};
    }
    return parseNutritionAiJson(text);
  }
}
