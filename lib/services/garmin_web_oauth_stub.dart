import 'dart:async';

Uri? garminWebCurrentUri() => null;

Uri garminWebOAuthReturnPageUri() =>
    Uri.parse('https://localhost/garmin_oauth_return.html');

Uri garminWebOAuthStartPageUri() =>
    Uri.parse('https://localhost/garmin_oauth_start.html');

Uri garminWebOAuthPreparePageUri() =>
    Uri.parse('https://localhost/garmin_oauth_prepare.html');

/// Directory dell'app web (origine + path base), slash finale — inviata al server come `app_return_base`.
Uri garminWebAppReturnBaseUri() => Uri.parse('https://localhost/');

/// Dopo redirect dal Pi: `?garmin_oauth=ok` o `garmin_oauth_err=` → consuma e pulisce la query.
Map<String, String>? garminWebConsumeServerCasOAuthQuery() => null;

void garminWebNavigateToGarminOAuthPreparePage({
  String? uid,
  String? apiBase,
}) {
  throw UnsupportedError('Garmin web OAuth: solo su piattaforma web');
}

Future<Map<String, dynamic>?> garminWebOAuthViaPopup(
  String ssoUrl, {
  Duration timeout = const Duration(minutes: 5),
}) async => null;

/// Su web reale vedi `garmin_web_oauth_web.dart` (iOS / PWA standalone → SSO full-page).
bool garminWebPreferGarminSsoFullPage() => false;

bool garminWebOpenPopup(String url) => false;

void garminWebAssignLocation(String url) {
  throw UnsupportedError('Garmin web OAuth: solo su piattaforma web');
}

void garminWebReplaceCleanUrl(Uri clean) {}

void garminWebSessionSet(String key, String value) {}

String? garminWebSessionGet(String key) => null;

void garminWebSessionRemove(String key) {}
