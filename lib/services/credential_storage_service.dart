import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Salvataggio sicuro di email e password per auto-login (flag "Ricordami").
final credentialStorageServiceProvider = Provider<CredentialStorageService>((ref) {
  return CredentialStorageService();
});

class CredentialStorageService {
  static const _emailKey = 'saved_login_email';
  static const _passwordKey = 'saved_login_password';
  static const _rememberKey = 'saved_login_remember';

  final _storage = const FlutterSecureStorage();

  /// Salva email e password se rememberMe è true.
  Future<void> saveCredentials({
    required String email,
    required String password,
    required bool rememberMe,
  }) async {
    try {
      if (rememberMe) {
        await _storage.write(key: _emailKey, value: email.trim());
        await _storage.write(key: _passwordKey, value: password);
        await _storage.write(key: _rememberKey, value: 'true');
      } else {
        await clearCredentials();
      }
    } catch (_) {
      // Ignora errori storage (es. file bloccato su Windows)
    }
  }

  /// Restituisce le credenziali salvate, se presenti.
  /// Su Windows, il file può essere corrotto o bloccato: in quel caso ritorna null.
  Future<({String email, String password})?> getCredentials() async {
    try {
      final remember = await _storage.read(key: _rememberKey);
      if (remember != 'true') return null;

      final email = await _storage.read(key: _emailKey);
      final password = await _storage.read(key: _passwordKey);

      if (email == null || password == null || email.isEmpty || password.isEmpty) {
        return null;
      }
      return (email: email, password: password);
    } catch (_) {
      // File corrotto, bloccato da altro processo, o CryptUnprotectData fallito (Windows)
      return null;
    }
  }

  /// Cancella le credenziali salvate (es. al logout).
  Future<void> clearCredentials() async {
    try {
      await _storage.delete(key: _emailKey);
      await _storage.delete(key: _passwordKey);
      await _storage.delete(key: _rememberKey);
    } catch (_) {
      // Ignora errori (es. file bloccato)
    }
  }
}
