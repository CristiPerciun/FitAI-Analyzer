import 'package:app_links/app_links.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:fitai_analyzer/app.dart';
import 'package:fitai_analyzer/firebase_options.dart';
import 'package:fitai_analyzer/services/strava_oauth_callback.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await dotenv.load(fileName: '.env');
  } catch (_) {
    // .env non disponibile (es. CI senza asset) - usa fallback in api_constants
  }
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Deep link per Strava OAuth (fallback iOS quando ASWebAuthenticationSession non apre)
  _setupStravaOAuthDeepLinks();

  runApp(const ProviderScope(child: MyApp()));
}

void _setupStravaOAuthDeepLinks() {
  final appLinks = AppLinks();
  void handleLink(Uri? uri) {
    StravaOAuthCallback.instance.handleUri(uri);
  }

  appLinks.uriLinkStream.listen(handleLink);
  appLinks.getInitialLink().then(handleLink);
  // getLatestLink aiuta quando l'app torna da background (es. da Safari)
  appLinks.getLatestLink().then(handleLink);
}
