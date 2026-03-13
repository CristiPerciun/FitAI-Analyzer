import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_generative_ai/google_generative_ai.dart';

import '../utils/api_constants.dart';

final geminiServiceProvider = Provider<GeminiService>((ref) => GeminiService());

class GeminiService {
  GenerativeModel? _model;
  GenerativeModel? _modelNutrition;

  GenerativeModel get _getModel {
    _model ??= GenerativeModel(
      model: 'gemini-2.5-flash',
      apiKey: ApiConstants.geminiApiKey,
    );
    return _model!;
  }

  /// Modello per analisi nutrizione da foto (JSON forced).
  GenerativeModel get _getModelNutrition {
    _modelNutrition ??= GenerativeModel(
      model: 'gemini-2.5-flash',
      apiKey: ApiConstants.geminiApiKey,
      generationConfig: GenerationConfig(
        responseMimeType: 'application/json',
      ),
    );
    return _modelNutrition!;
  }

  void _checkApiKey() {
    if (ApiConstants.geminiApiKey.isEmpty ||
        ApiConstants.geminiApiKey.startsWith('INSERISCI_QUI')) {
      throw StateError(
        'Configura GEMINI_API_KEY nel file .env '
        '(ottienila da aistudio.google.com/apikey)',
      );
    }
  }

  /// Invia il contesto completo a Gemini e restituisce l'analisi.
  /// [context] - output di AiPromptService.buildFullAIContext
  /// Usato per report annuale e piano settimanale.
  Future<String> analyzeFitnessContext(String context) async {
    _checkApiKey();

    final prompt = '''
$context

---

Sulla base del contesto sopra, fornisci:
1. Analisi scientifica personalizzata del profilo fitness
2. Piano settimanale concreto (allenamenti, Zone 2, nutrizione)
3. Raccomandazioni basate su Peter Attia (Outlive) e longevità

Rispondi in italiano, in modo strutturato e actionable.
''';

    final response = await _getModel.generateContent([Content.text(prompt)]);

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
    _checkApiKey();

    final imagePart = DataPart(mimeType, imageBytes);

    const prompt = '''
Analizza questa foto di un piatto/cibo. Sei un nutrizionista.

Restituisci un JSON con questo schema esatto:
{
  "total_calories": numero,
  "protein_g": numero,
  "carbs_g": numero,
  "fat_g": numero,
  "fiber_g": numero,
  "sugar_g": numero,
  "foods": [{"name": "stringa", "calories": numero, "portion": "stringa"}],
  "advice": "stringa con consigli nutrizionali brevi in italiano"
}

Stima le calorie e i macronutrienti in base al cibo visibile. Sii realistico.
''';

    final response = await _getModelNutrition.generateContent([
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
