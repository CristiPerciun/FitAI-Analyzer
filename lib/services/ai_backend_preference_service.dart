import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'gemini_api_key_service.dart';

/// Backend LLM selezionato dall'utente (mutuamente esclusivo).
enum AiBackend { gemini, deepseek, openrouter }

/// Stato letto per la UI Impostazioni.
class AiBackendSettingsSnapshot {
  const AiBackendSettingsSnapshot({
    required this.backend,
    required this.hasGeminiKey,
    required this.hasDeepSeekKey,
    required this.hasOpenRouterKey,
  });

  final AiBackend backend;
  final bool hasGeminiKey;
  final bool hasDeepSeekKey;
  final bool hasOpenRouterKey;
}

final aiBackendPreferenceServiceProvider =
    Provider<AiBackendPreferenceService>((ref) {
  return AiBackendPreferenceService();
});

/// Preferenza attiva (secure storage) + chiavi DeepSeek / OpenRouter.
/// La chiave Gemini resta in [GeminiApiKeyService].
class AiBackendPreferenceService {
  static const _backendKey = 'AI_ACTIVE_BACKEND';
  static const _deepseekKey = 'DEEPSEEK_API_KEY';
  static const _openRouterKey = 'OPENROUTER_API_KEY';

  final _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  Future<AiBackend> getBackend() async {
    final v = await _storage.read(key: _backendKey);
    if (v == 'deepseek') return AiBackend.deepseek;
    if (v == 'openrouter') return AiBackend.openrouter;
    return AiBackend.gemini;
  }

  Future<void> setBackend(AiBackend backend) async {
    final s = switch (backend) {
      AiBackend.deepseek => 'deepseek',
      AiBackend.openrouter => 'openrouter',
      AiBackend.gemini => 'gemini',
    };
    await _storage.write(key: _backendKey, value: s);
  }

  Future<String> getDeepSeekKey() async {
    final stored = await _storage.read(key: _deepseekKey);
    if (stored != null &&
        stored.isNotEmpty &&
        !stored.startsWith('INSERISCI')) {
      return stored;
    }
    return dotenv.get('DEEPSEEK_API_KEY', fallback: '');
  }

  Future<void> saveDeepSeekKey(String key) async {
    final trimmed = key.trim();
    if (trimmed.isEmpty) return;
    await _storage.write(key: _deepseekKey, value: trimmed);
  }

  Future<bool> hasValidDeepSeekKey() async {
    final k = await getDeepSeekKey();
    return k.isNotEmpty && !k.startsWith('INSERISCI');
  }

  Future<String> getOpenRouterKey() async {
    final stored = await _storage.read(key: _openRouterKey);
    if (stored != null &&
        stored.isNotEmpty &&
        !stored.startsWith('INSERISCI')) {
      return stored;
    }
    return dotenv.get('OPENROUTER_API_KEY', fallback: '');
  }

  Future<void> saveOpenRouterKey(String key) async {
    final trimmed = key.trim();
    if (trimmed.isEmpty) return;
    await _storage.write(key: _openRouterKey, value: trimmed);
  }

  Future<bool> hasValidOpenRouterKey() async {
    final k = await getOpenRouterKey();
    return k.isNotEmpty && !k.startsWith('INSERISCI');
  }

  /// Il backend selezionato ha una chiave API configurata.
  Future<bool> isActiveBackendConfigured(
    GeminiApiKeyService gemini,
  ) async {
    final b = await getBackend();
    return switch (b) {
      AiBackend.deepseek => await hasValidDeepSeekKey(),
      AiBackend.openrouter => await hasValidOpenRouterKey(),
      AiBackend.gemini => await gemini.hasValidKey(),
    };
  }
}
