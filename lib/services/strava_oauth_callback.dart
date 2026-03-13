import 'dart:async';

/// Gestisce il callback OAuth Strava su iOS quando si usa url_launcher
/// (fallback perché ASWebAuthenticationSession a volte non apre la pagina).
class StravaOAuthCallback {
  StravaOAuthCallback._();
  static final StravaOAuthCallback instance = StravaOAuthCallback._();

  static const String _scheme = 'myhealthsync';

  Completer<String>? _completer;

  /// Avvia l'attesa del callback. Chiamare prima di launchUrl.
  Future<String> waitForCallback({Duration timeout = const Duration(minutes: 5)}) {
    _completer = Completer<String>();
    return _completer!.future.timeout(timeout, onTimeout: () {
      _completer = null;
      throw TimeoutException('Timeout attesa autorizzazione Strava');
    });
  }

  /// Gestisce un URI in arrivo (da app_links). Ritorna true se era un callback Strava.
  /// myhealthsync://strava/callback?code=xxx → host=strava, path=/callback
  bool handleUri(Uri? uri) {
    if (uri == null) return false;
    if (uri.scheme != _scheme) return false;
    // Strava redirect: myhealthsync://strava/callback (host=strava) oppure myhealthsync://?code=...
    final isStrava = uri.host == 'strava' ||
        uri.path.contains('strava') ||
        uri.path.contains('callback') ||
        uri.queryParameters.containsKey('code') ||
        uri.queryParameters.containsKey('error');
    if (!isStrava) return false;

    final code = uri.queryParameters['code'];
    final error = uri.queryParameters['error'];
    final c = _completer;
    _completer = null;

    if (code != null) {
      c?.complete(code);
      return true;
    }
    if (error != null) {
      c?.completeError(Exception('Strava: $error'));
      return true;
    }
    return false;
  }
}
