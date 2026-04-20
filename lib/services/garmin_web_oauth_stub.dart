import 'dart:async';

Uri? garminWebCurrentUri() => null;

Uri garminWebOAuthReturnPageUri() =>
    Uri.parse('https://localhost/garmin_oauth_return.html');

Uri garminWebOAuthStartPageUri() =>
    Uri.parse('https://localhost/garmin_oauth_start.html');

Future<String?> garminWebOAuthViaPopup(
  String ssoUrl, {
  Duration timeout = const Duration(minutes: 5),
}) async => null;

bool garminWebOpenPopup(String url) => false;

void garminWebAssignLocation(String url) {
  throw UnsupportedError('Garmin web OAuth: solo su piattaforma web');
}

void garminWebReplaceCleanUrl(Uri clean) {}

void garminWebSessionSet(String key, String value) {}

String? garminWebSessionGet(String key) => null;

void garminWebSessionRemove(String key) {}
