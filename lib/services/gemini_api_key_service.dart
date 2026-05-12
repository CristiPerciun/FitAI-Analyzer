import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Servizio per la chiave API Gemini.
///
/// La chiave in Secure Storage è **per UID** (`GEMINI_API_KEY_UID::<uid>`), così due account
/// sullo stesso dispositivo non condividono la stessa API key.
/// Priorità per [getKey]: 1) slot dell’utente corrente, 2) `.env` (sviluppo).
///
/// Lo slot legacy globale `GEMINI_API_KEY` (pre-fix) viene eliminato al salvataggio / dopo sync
/// cloud per evitare fughe tra account.
final geminiApiKeyServiceProvider = Provider<GeminiApiKeyService>((ref) {
  return GeminiApiKeyService();
});

class GeminiApiKeyService {
  /// Slot condiviso usato dalle versioni precedenti (una sola chiave per dispositivo).
  static const _legacySharedKey = 'GEMINI_API_KEY';

  /// Heuristica: le chiavi Google usate dall’SDK Gemini iniziano con `AIza` (mai `sk-or-`,
  /// `sk-` DeepSeek/OpenRouter ecc.). Serve a evitare che una chiave errata nel Keychain
  /// blocchi `.env` o venga caricata su Firebase come `gemini_api_key`.
  static bool isPlausibleGeminiApiKey(String key) {
    final t = key.trim();
    if (t.isEmpty || t.startsWith('INSERISCI')) return false;
    return t.startsWith('AIza');
  }

  final _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  static String _scopedStorageKey(String uid) => 'GEMINI_API_KEY_UID::$uid';

  Future<void> _deleteScopedKey(String uid) async {
    await _storage.delete(key: _scopedStorageKey(uid));
  }

  /// Rimuove lo slot legacy condiviso (chiamata dopo login/sync o dopo aver scritto per UID).
  Future<void> deleteLegacySharedKeyIfAny() async {
    await _storage.delete(key: _legacySharedKey);
  }

  /// Restituisce la chiave: slot per [uid], poi `.env` (nessuna lettura dello slot legacy condiviso).
  Future<String> getKey({String? uid}) async {
    if (uid != null && uid.isNotEmpty) {
      final stored = await _storage.read(key: _scopedStorageKey(uid));
      if (stored != null &&
          stored.isNotEmpty &&
          !stored.startsWith('INSERISCI')) {
        if (isPlausibleGeminiApiKey(stored)) return stored;
        await _deleteScopedKey(uid);
      }
    }
    final env = dotenv.get('GEMINI_API_KEY', fallback: '').trim();
    if (isPlausibleGeminiApiKey(env)) return env;
    return '';
  }

  /// Salva la chiave nello slot dedicato all’utente e invalida lo slot legacy condiviso.
  Future<void> saveKey(String key, {required String uid}) async {
    final trimmed = key.trim();
    if (trimmed.isEmpty || !isPlausibleGeminiApiKey(trimmed)) return;
    await _storage.write(key: _scopedStorageKey(uid), value: trimmed);
    await deleteLegacySharedKeyIfAny();
  }

  /// Verifica se la chiave è configurata per l’utente ([uid]) o, senza utente, solo `.env`.
  Future<bool> hasValidKey({String? uid}) async {
    final k = await getKey(uid: uid);
    return k.isNotEmpty && !k.startsWith('INSERISCI');
  }

  /// Solo Secure Storage per [uid] (niente fallback `.env`).
  Future<String> readSecureStorageKeyOrEmpty({required String uid}) async {
    final stored = await _storage.read(key: _scopedStorageKey(uid));
    if (stored != null &&
        stored.isNotEmpty &&
        !stored.startsWith('INSERISCI')) {
      if (isPlausibleGeminiApiKey(stored)) return stored;
      await _deleteScopedKey(uid);
    }
    return '';
  }
}
