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

  final _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  static String _scopedStorageKey(String uid) => 'GEMINI_API_KEY_UID::$uid';

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
        return stored;
      }
    }
    return dotenv.get('GEMINI_API_KEY', fallback: '');
  }

  /// Salva la chiave nello slot dedicato all’utente e invalida lo slot legacy condiviso.
  Future<void> saveKey(String key, {required String uid}) async {
    final trimmed = key.trim();
    if (trimmed.isEmpty) return;
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
      return stored;
    }
    return '';
  }
}
