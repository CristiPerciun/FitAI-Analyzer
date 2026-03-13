import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Servizio per la chiave API Gemini.
/// Priorità: 1) Secure Storage (per iOS/dispositivo), 2) .env (per sviluppo locale).
/// Su iOS puoi inserire la chiave nell'app e viene salvata in Secure Storage.
final geminiApiKeyServiceProvider = Provider<GeminiApiKeyService>((ref) {
  return GeminiApiKeyService();
});

class GeminiApiKeyService {
  static const _key = 'GEMINI_API_KEY';
  final _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  /// Restituisce la chiave: prima da Secure Storage, poi da .env.
  Future<String> getKey() async {
    final stored = await _storage.read(key: _key);
    if (stored != null && stored.isNotEmpty && !stored.startsWith('INSERISCI')) {
      return stored;
    }
    return dotenv.get('GEMINI_API_KEY', fallback: '');
  }

  /// Salva la chiave in Secure Storage (per uso su dispositivo iOS).
  Future<void> saveKey(String key) async {
    final trimmed = key.trim();
    if (trimmed.isEmpty) return;
    await _storage.write(key: _key, value: trimmed);
  }

  /// Verifica se la chiave è configurata.
  Future<bool> hasValidKey() async {
    final k = await getKey();
    return k.isNotEmpty && !k.startsWith('INSERISCI');
  }
}
