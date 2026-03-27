import 'dart:async';

/// Gestisce il callback Garmin su mobile quando si usa il browser esterno.
class GarminOAuthCallback {
  GarminOAuthCallback._();
  static final GarminOAuthCallback instance = GarminOAuthCallback._();

  static const String _scheme = 'myhealthsync';

  Completer<String>? _completer;

  /// Avvia l'attesa del callback Garmin. Chiamare prima di aprire Safari/Chrome.
  Future<String> waitForCallback({
    Duration timeout = const Duration(minutes: 5),
  }) {
    _completer = Completer<String>();
    return _completer!.future.timeout(
      timeout,
      onTimeout: () {
        _completer = null;
        throw TimeoutException('Timeout attesa autorizzazione Garmin');
      },
    );
  }

  /// Gestisce un URI in arrivo: myhealthsync://garmin/callback?ticket=ST-...
  bool handleUri(Uri? uri) {
    if (uri == null) return false;
    if (uri.scheme != _scheme) return false;
    final isGarmin =
        uri.host == 'garmin' ||
        uri.path.contains('garmin') ||
        uri.path.contains('callback') ||
        uri.queryParameters.containsKey('ticket') ||
        uri.queryParameters.containsKey('error');
    if (!isGarmin) return false;

    final ticket = uri.queryParameters['ticket'];
    final error = uri.queryParameters['error'];
    final c = _completer;
    _completer = null;

    if (ticket != null && ticket.isNotEmpty) {
      c?.complete(uri.toString());
      return true;
    }
    if (error != null && error.isNotEmpty) {
      c?.completeError(Exception('Garmin: $error'));
      return true;
    }
    c?.completeError(Exception('Autorizzazione Garmin annullata'));
    return true;
  }
}
