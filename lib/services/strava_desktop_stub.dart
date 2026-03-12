/// Stub per piattaforme senza dart:io (es. web).
Future<String> runDesktopStravaOAuth(
  String authUrlBase,
  Map<String, String> params,
) async {
  throw UnsupportedError('Strava OAuth desktop non disponibile su questa piattaforma');
}
