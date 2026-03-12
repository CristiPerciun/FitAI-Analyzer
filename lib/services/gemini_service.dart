import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_generative_ai/google_generative_ai.dart';

import '../utils/api_constants.dart';

final geminiServiceProvider = Provider<GeminiService>((ref) => GeminiService());

class GeminiService {
  GenerativeModel? _model;

  GenerativeModel get _getModel {
    _model ??= GenerativeModel(
      model: 'gemini-1.5-flash',
      apiKey: ApiConstants.geminiApiKey,
    );
    return _model!;
  }

  /// Invia il contesto completo a Gemini e restituisce l'analisi.
  /// [context] - output di AiPromptService.buildFullAIContext
  Future<String> analyzeFitnessContext(String context) async {
    if (ApiConstants.geminiApiKey.isEmpty ||
        ApiConstants.geminiApiKey.startsWith('INSERISCI_QUI')) {
      throw StateError(
        'Configura geminiApiKey in lib/utils/api_constants.dart '
        '(ottienila da aistudio.google.com/apikey)',
      );
    }

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
}
