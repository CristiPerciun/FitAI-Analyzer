Uri? stravaWebCurrentUri() => null;

void stravaWebAssignLocation(String url) {
  throw UnsupportedError('Strava web OAuth: solo su piattaforma web');
}

void stravaWebReplaceCleanUrl(Uri clean) {}

void stravaWebSessionSet(String key, String value) {}

String? stravaWebSessionGet(String key) => null;

void stravaWebSessionRemove(String key) {}

String stravaWebNewOAuthState() => '';
