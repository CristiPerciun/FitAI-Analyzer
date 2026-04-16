Uri? garminWebCurrentUri() => null;

void garminWebAssignLocation(String url) {
  throw UnsupportedError('Garmin web OAuth: solo su piattaforma web');
}

void garminWebReplaceCleanUrl(Uri clean) {}

void garminWebSessionSet(String key, String value) {}

String? garminWebSessionGet(String key) => null;

void garminWebSessionRemove(String key) {}
