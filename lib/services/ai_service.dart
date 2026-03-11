import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

/// Servizio per generazione piani AI.
/// Prompts basati su linee guida universitarie (Harvard, WHO, ecc.)
/// API: OpenAI, Gemini, o compatibili.
class AiService {
  AiService({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  static const _defaultBaseUrl = 'https://api.openai.com/v1';

  /// Prompt system basato su fonti scientifiche.
  /// Riferimenti: Harvard T.H. Chan School of Public Health, WHO, ACSM.
  static const _systemPrompt = '''
Sei un esperto di fitness e nutrizione. I tuoi consigli devono basarsi su:
- Linee guida Harvard T.H. Chan School of Public Health (Healthy Eating Plate)
- Raccomandazioni WHO per attività fisica (150-300 min/settimana moderata)
- American College of Sports Medicine (ACSM) per programmazione allenamento
- Evidence-based practice: cita fonti quando possibile

Rispondi in modo chiaro, strutturato e personalizzato. Evita consigli generici.
''';

  Future<String?> getStoredApiKey() async {
    return _storage.read(key: 'ai_api_key');
  }

  Future<String> generatePlan({
    required String userContext,
    required String goals,
    String? apiKey,
    String? baseUrl,
  }) async {
    try {
      final key = apiKey ?? await getStoredApiKey();
      if (key == null || key.isEmpty) {
        throw StateError(
          'API key mancante. Salvala in Secure Storage con chiave "ai_api_key".',
        );
      }

      final url = baseUrl ?? _defaultBaseUrl;
      final body = {
        'model': 'gpt-4o-mini',
        'messages': [
          {'role': 'system', 'content': _systemPrompt},
          {
            'role': 'user',
            'content': '''
Contesto utente:
$userContext

Obiettivi:
$goals

Genera un piano personalizzato (allenamento + nutrizione) basato su evidenze scientifiche.
''',
          },
        ],
        'temperature': 0.7,
        'max_tokens': 1500,
      };

      final response = await http.post(
        Uri.parse('$url/chat/completions'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $key',
        },
        body: jsonEncode(body),
      );

      if (response.statusCode == 401) {
        throw Exception('API key non valida');
      }
      if (response.statusCode != 200) {
        throw Exception('AI API error: ${response.statusCode} - ${response.body}');
      }

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final choices = json['choices'] as List?;
      if (choices == null || choices.isEmpty) {
        throw Exception('Risposta API vuota');
      }
      final content = choices.first['message']?['content'] as String?;
      return content ?? 'Errore nel parsing della risposta.';
    } catch (e) {
      rethrow;
    }
  }

  /// Salva API key in Secure Storage.
  Future<void> saveApiKey(String key) async {
    await _storage.write(key: 'ai_api_key', value: key);
  }
}
