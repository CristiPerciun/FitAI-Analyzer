import 'package:app_links/app_links.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:fitai_analyzer/app.dart';
import 'package:fitai_analyzer/firebase_options.dart';
import 'package:fitai_analyzer/services/garmin_oauth_callback.dart';
import 'package:fitai_analyzer/services/strava_oauth_callback.dart';
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await dotenv.load(fileName: '.env');
  } catch (_) {
    // .env non disponibile (es. CI senza asset) - GeminiApiKeyService usa fallback
  }
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Workaround per thread Firestore su Windows: clear cache prima del primo uso
  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.windows) {
    try {
      await FirebaseFirestore.instance.clearPersistence();
    } catch (_) {}
  }

  // Deep link OAuth custom-scheme per Strava e Garmin.
  _setupOAuthDeepLinks();

  runApp(const ProviderScope(child: MyApp()));
}

void _setupOAuthDeepLinks() {
  final appLinks = AppLinks();
  void handleLink(Uri? uri) {
    StravaOAuthCallback.instance.handleUri(uri);
    GarminOAuthCallback.instance.handleUri(uri);
  }

  appLinks.uriLinkStream.listen(handleLink);
  appLinks.getInitialLink().then(handleLink);
  // getLatestLink aiuta quando l'app torna da background (es. da Safari)
  appLinks.getLatestLink().then(handleLink);
}
