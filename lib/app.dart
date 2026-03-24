import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:fitai_analyzer/providers/auth_notifier.dart';
import 'package:fitai_analyzer/providers/garmin_sync_notifier.dart';
import 'package:fitai_analyzer/providers/sync_backfill_status_provider.dart';
import 'package:fitai_analyzer/services/aggregation_service.dart';
import 'package:fitai_analyzer/providers/theme_mode_provider.dart';
import 'package:fitai_analyzer/routes/app_router.dart';
import 'package:fitai_analyzer/services/strava_oauth_callback.dart';
import 'package:fitai_analyzer/theme/app_theme.dart';
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

    ref.listen<String?>(authNotifierProvider.select((s) => s.user?.uid), (prev, next) {
      if (next == null || next == prev) return;
      unawaited(ref.read(garminSyncNotifierProvider.notifier).syncNow(
            uid: next,
            trigger: 'login',
          ));
    });

    ref.listen<AsyncValue<SyncBackfillStatus?>>(syncBackfillStatusStreamProvider, (prev, next) {
      final was = prev?.valueOrNull?.status;
      final now = next.valueOrNull?.status;
      if (now != 'completed') return;
      if (was != 'processing' && was != 'pending') return;
      final uid = ref.read(authNotifierProvider).user?.uid;
      if (uid == null) return;
      unawaited(
        ref.read(aggregationServiceProvider).updateRolling10DaysAndBaseline(uid),
      );
    });

    // Mostra errori auth anche quando si è navigati via (es. redirect a dashboard)
    ref.listen<String?>(authNotifierProvider.select((s) => s.error), (prev, next) {
      if (next != null && next.isNotEmpty && next != prev) {
        scaffoldMessengerKey.currentState?.showSnackBar(
          SnackBar(
            content: Text(next),
            backgroundColor: AppColors.error,
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

    ref.listen(
      garminSyncNotifierProvider.select((s) => (s.error, s.trigger)),
      (prev, next) {
        final error = next.$1;
        if (error == null || error.isEmpty || next == prev) return;
        // Non mostrare errore per pull-to-refresh: l'utente ha scrollato, non serve SnackBar
        final trigger = next.$2 ?? '';
        if (trigger.contains('pull_to_refresh') ||
            trigger.contains('settings_')) {
          ref.read(garminSyncNotifierProvider.notifier).clearError();
          return;
        }
        scaffoldMessengerKey.currentState?.showSnackBar(
          SnackBar(
            content: Text(error),
            backgroundColor: AppColors.error,
            duration: const Duration(seconds: 6),
          ),
        );
        ref.read(garminSyncNotifierProvider.notifier).clearError();
      },
    );

    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp.router(
      scaffoldMessengerKey: scaffoldMessengerKey,
      title: 'FitAI Analyzer',
      theme: appLightTheme,
      darkTheme: appDarkTheme,
      themeMode: themeMode,
      routerConfig: router,
    );
  }
}
