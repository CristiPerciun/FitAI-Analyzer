import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Costanti API per servizi esterni.
/// Chiave Gemini da .env (GEMINI_API_KEY).
class ApiConstants {
  ApiConstants._();

  /// Gemini API key (aistudio.google.com/apikey) - letta da .env
  static String get geminiApiKey =>
      dotenv.get('GEMINI_API_KEY', fallback: 'INSERISCI_QUI_LA_TUA_GEMINI_API_KEY');
}
