import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_generative_ai/google_generative_ai.dart';

import 'gemini_api_key_service.dart';

final geminiServiceProvider = Provider<GeminiService>((ref) {
  final apiKeyService = ref.watch(geminiApiKeyServiceProvider);
  return GeminiService(apiKeyService: apiKeyService);
});

class GeminiService {
  GeminiService({required GeminiApiKeyService apiKeyService})
      : _apiKeyService = apiKeyService;

  final GeminiApiKeyService _apiKeyService;

  GenerativeModel? _model;
  GenerativeModel? _modelNutrition;
  String? _lastKey;

  Future<GenerativeModel> _getModel() async {
    final key = await _apiKeyService.getKey();
    _checkApiKey(key);
    if (_model == null || _lastKey != key) {
      _lastKey = key;
      _model = GenerativeModel(model: 'gemini-2.5-flash', apiKey: key);
    }
    return _model!;
  }

  Future<GenerativeModel> _getModelNutrition() async {
    final key = await _apiKeyService.getKey();
    _checkApiKey(key);
    if (_modelNutrition == null || _lastKey != key) {
      _lastKey = key;
      _modelNutrition = GenerativeModel(
        model: 'gemini-2.5-flash',
        apiKey: key,
        generationConfig: GenerationConfig(
          responseMimeType: 'application/json',
        ),
      );
    }
    return _modelNutrition!;
  }

  void _checkApiKey(String key) {
    if (key.isEmpty || key.startsWith('INSERISCI_QUI')) {
      throw StateError(
        'Configura la chiave Gemini: inseriscila nell\'app (Impostazioni) '
        'o nel file .env (ottienila da aistudio.google.com/apikey)',
      );
    }
  }

  /// Invia il contesto completo a Gemini e restituisce l'analisi.
  /// [context] - output di AiPromptService.buildFullAIContext
  /// Usato per report annuale e piano settimanale.
  Future<String> analyzeFitnessContext(String context) async {
    final model = await _getModel();

    final prompt = '''
$context

---

Sulla base del contesto sopra, fornisci:
1. Analisi scientifica personalizzata del profilo fitness
2. Piano settimanale concreto (allenamenti, Zone 2, nutrizione)
3. Raccomandazioni basate su Peter Attia (Outlive) e longevità

Rispondi in italiano, in modo strutturato e actionable.
''';

    final response = await model.generateContent([Content.text(prompt)]);

    final text = response.text;
    if (text == null || text.isEmpty) {
      throw Exception('Gemini non ha restituito risposta');
    }

    return text;
  }

  /// Analizza una foto di piatto e restituisce dati nutrizionali in JSON.
  /// [imageBytes] - bytes dell'immagine (JPEG/PNG).
  /// [mimeType] - 'image/jpeg' (default) o 'image/png'.
  /// Ritorna Map con total_calories, protein_g, carbs_g, fat_g, fiber_g, sugar_g,
  /// foods (lista), advice (consigli).
  Future<Map<String, dynamic>> analyzeNutritionFromImage(
    Uint8List imageBytes, {
    String mimeType = 'image/jpeg',
  }) async {
    final model = await _getModelNutrition();

    final imagePart = DataPart(mimeType, imageBytes);

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

    final response = await model.generateContent([
      Content.multi([TextPart(prompt), imagePart])
    ]);

    final text = response.text;
    if (text == null || text.isEmpty) {
      throw Exception('Gemini non ha restituito risposta per la foto');
    }

    return _parseNutritionJson(text);
  }

  Map<String, dynamic> _parseNutritionJson(String raw) {
    try {
      final cleaned = raw
          .replaceAll(RegExp(r'```json\s*'), '')
          .replaceAll(RegExp(r'\s*```'), '')
          .trim();
      final decoded = json.decode(cleaned) as Map<String, dynamic>?;
      return decoded ?? {'raw': raw, 'error': 'JSON vuoto'};
    } catch (_) {
      return {'raw': raw, 'error': 'JSON non valido'};
    }
  }
}
