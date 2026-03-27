import 'dart:async';

class GarminOAuthCallback {
  GarminOAuthCallback._();
  static final GarminOAuthCallback instance = GarminOAuthCallback._();

  static const String _scheme = 'myhealthsync';

  Completer<String>? _completer;

  Future<String> waitForCallback({
    Duration timeout = const Duration(minutes: 5),
  }) {
    _completer = Completer<String>();
    return _completer!.future.timeout(
      timeout,
      onTimeout: () {
        _completer = null;
        throw TimeoutException('Timeout attesa login Garmin da browser');
      },
    );
  }

  bool handleUri(Uri? uri) {
    if (uri == null) return false;
    if (uri.scheme != _scheme) return false;
    final isGarmin = uri.host == 'garmin' || uri.path.contains('garmin');
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
    c?.completeError(Exception('Login Garmin annullato o ticket non ricevuto'));
    return true;
  }
}
