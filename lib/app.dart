import 'package:app_links/app_links.dart';
import 'package:fitai_analyzer/routes/app_router.dart';
import 'package:fitai_analyzer/services/strava_oauth_callback.dart';
import 'package:fitai_analyzer/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class MyApp extends ConsumerStatefulWidget {
  const MyApp({super.key});

  @override
  ConsumerState<MyApp> createState() => _MyAppState();
}

class _MyAppState extends ConsumerState<MyApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Quando l'app torna attiva (es. da Safari/Chrome), controlla link in sospeso
      AppLinks().getLatestLink().then((uri) {
        StravaOAuthCallback.instance.handleUri(uri);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(appRouterProvider);

    return MaterialApp.router(
      title: 'FitAI Analyzer',
      theme: appLightTheme,
      darkTheme: appDarkTheme,
      themeMode: ThemeMode.system,
      routerConfig: router,
    );
  }
}
