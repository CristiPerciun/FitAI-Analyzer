import 'package:app_links/app_links.dart';
import 'package:fitai_analyzer/providers/auth_notifier.dart';
import 'package:fitai_analyzer/routes/app_router.dart';
import 'package:fitai_analyzer/services/strava_oauth_callback.dart';
import 'package:fitai_analyzer/theme/app_theme.dart';
import 'package:fitai_analyzer/ui/theme/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Chiave globale per mostrare SnackBar da qualsiasi punto (es. errori auth).
final scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

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

    // Mostra errori auth anche quando si è navigati via (es. redirect a dashboard)
    ref.listen<String?>(authNotifierProvider.select((s) => s.error), (prev, next) {
      if (next != null && next.isNotEmpty && next != prev) {
        scaffoldMessengerKey.currentState?.showSnackBar(
          SnackBar(
            content: Text(next),
            backgroundColor: AppColors.errorRed,
            duration: const Duration(seconds: 8),
            action: SnackBarAction(
              label: 'OK',
              textColor: AppColors.white,
              onPressed: () =>
                  scaffoldMessengerKey.currentState?.hideCurrentSnackBar(),
            ),
          ),
        );
      }
    });

    return MaterialApp.router(
      scaffoldMessengerKey: scaffoldMessengerKey,
      title: 'FitAI Analyzer',
      theme: appLightTheme,
      darkTheme: appDarkTheme,
      themeMode: ThemeMode.system,
      routerConfig: router,
    );
  }
}
