import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'ai_backend_preference_service.dart';
import 'gemini_api_key_service.dart';

/// Sincronizza chiavi IA e backend attivo su Firestore (`users/{uid}/app_sync/ai_keys`)
/// così PC e cellulare con lo stesso account condividono la configurazione.
final userAiSettingsSyncServiceProvider =
    Provider<UserAiSettingsSyncService>((ref) {
  return UserAiSettingsSyncService(
    FirebaseFirestore.instance,
    ref.read(geminiApiKeyServiceProvider),
    ref.read(aiBackendPreferenceServiceProvider),
  );
});

class UserAiSettingsSyncService {
  UserAiSettingsSyncService(
    this._firestore,
    this._gemini,
    this._backendPrefs,
  );

  final FirebaseFirestore _firestore;
  final GeminiApiKeyService _gemini;
  final AiBackendPreferenceService _backendPrefs;

  DocumentReference<Map<String, dynamic>> _doc(String uid) {
    return _firestore
        .collection('users')
        .doc(uid)
        .collection('app_sync')
        .doc('ai_keys');
  }

  /// Scarica da cloud e scrive in Secure Storage (solo campi non vuoti in cloud).
  Future<void> pullFromCloud(String uid) async {
    final snap = await _doc(uid).get();
    if (!snap.exists) return;
    final d = snap.data() ?? {};

    final gemini = d['gemini_api_key']?.toString().trim() ?? '';
    if (gemini.isNotEmpty && !gemini.startsWith('INSERISCI')) {
      await _gemini.saveKey(gemini);
    }

    final deepseek = d['deepseek_api_key']?.toString().trim() ?? '';
    if (deepseek.isNotEmpty && !deepseek.startsWith('INSERISCI')) {
      await _backendPrefs.saveDeepSeekKey(deepseek);
    }

    final openrouter = d['openrouter_api_key']?.toString().trim() ?? '';
    if (openrouter.isNotEmpty && !openrouter.startsWith('INSERISCI')) {
      await _backendPrefs.saveOpenRouterKey(openrouter);
    }

    final backend = d['active_backend']?.toString();
    if (backend == 'deepseek') {
      await _backendPrefs.setBackend(AiBackend.deepseek);
    } else if (backend == 'openrouter') {
      await _backendPrefs.setBackend(AiBackend.openrouter);
    } else if (backend == 'gemini') {
      await _backendPrefs.setBackend(AiBackend.gemini);
    }
  }

  Future<void> _merge(String uid, Map<String, dynamic> fields) async {
    await _doc(uid).set(
      {
        ...fields,
        'updated_at': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }

  Future<void> saveGeminiKeyLocalAndCloud(String uid, String key) async {
    final trimmed = key.trim();
    if (trimmed.isEmpty) return;
    await _gemini.saveKey(trimmed);
    await _merge(uid, {'gemini_api_key': trimmed});
  }

  Future<void> saveDeepSeekKeyLocalAndCloud(String uid, String key) async {
    final trimmed = key.trim();
    if (trimmed.isEmpty) return;
    await _backendPrefs.saveDeepSeekKey(trimmed);
    await _merge(uid, {'deepseek_api_key': trimmed});
  }

  Future<void> saveOpenRouterKeyLocalAndCloud(String uid, String key) async {
    final trimmed = key.trim();
    if (trimmed.isEmpty) return;
    await _backendPrefs.saveOpenRouterKey(trimmed);
    await _merge(uid, {'openrouter_api_key': trimmed});
  }

  Future<void> pushActiveBackend(String uid, AiBackend backend) async {
    final s = switch (backend) {
      AiBackend.deepseek => 'deepseek',
      AiBackend.openrouter => 'openrouter',
      AiBackend.gemini => 'gemini',
    };
    await _merge(uid, {'active_backend': s});
  }
}
