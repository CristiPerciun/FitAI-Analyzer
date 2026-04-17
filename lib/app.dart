import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:fitai_analyzer/providers/auth_notifier.dart';
import 'package:fitai_analyzer/providers/data_sync_notifier.dart';
import 'package:fitai_analyzer/providers/garmin_sync_notifier.dart';
import 'package:fitai_analyzer/providers/sync_backfill_status_provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fitai_analyzer/services/aggregation_service.dart';
import 'package:fitai_analyzer/services/garmin_oauth_callback.dart';
import 'package:fitai_analyzer/services/garmin_service.dart';
import 'package:fitai_analyzer/providers/theme_mode_provider.dart';
import 'package:fitai_analyzer/routes/app_router.dart';
import 'package:fitai_analyzer/services/strava_oauth_callback.dart';
import 'package:fitai_analyzer/services/strava_service.dart';
import 'package:fitai_analyzer/theme/app_theme.dart';
import 'package:fitai_analyzer/utils/ios_pwa_chrome.dart';
import 'package:fitai_analyzer/utils/strava_error_messages.dart';
import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
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
    if (kIsWeb) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        unawaited(_resumeStravaWebOAuthIfNeeded());
        unawaited(_resumeGarminWebOAuthIfNeeded());
        _syncIosPwaChrome();
      });
    }
  }

  Brightness _effectiveBrightness(ThemeMode mode, Brightness platform) {
    return switch (mode) {
      ThemeMode.light => Brightness.light,
      ThemeMode.dark => Brightness.dark,
      ThemeMode.system => platform,
    };
  }

  void _syncIosPwaChrome() {
    if (!kIsWeb) return;
    final mode = ref.read(themeModeProvider);
    final platform =
        WidgetsBinding.instance.platformDispatcher.platformBrightness;
    syncIosPwaDocumentForTheme(_effectiveBrightness(mode, platform));
  }

  /// Strava su web: dopo redirect da strava.com l’URL contiene ?code= — exchange via server + sync token.
  Future<void> _resumeStravaWebOAuthIfNeeded() async {
    if (!kIsWeb || !mounted) return;
    var uid =
        FirebaseAuth.instance.currentUser?.uid ??
        ref.read(authNotifierProvider).user?.uid;
    if (uid == null) {
      for (var i = 0; i < 50; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 100));
        if (!mounted) return;
        uid =
            FirebaseAuth.instance.currentUser?.uid ??
            ref.read(authNotifierProvider).user?.uid;
        if (uid != null) break;
      }
    }
    if (uid == null) return;

    final strava = ref.read(stravaServiceProvider);
    final garmin = ref.read(garminServiceProvider);
    try {
      final done = await strava.completeWebOAuthIfPresent(
        garminService: garmin,
        uid: uid,
      );
      if (!done || !mounted) return;
      await ref
          .read(authNotifierProvider.notifier)
          .syncStravaToServerAfterWebOAuth();
    } catch (e, st) {
      debugPrint('Strava web OAuth: $e\n$st');
      if (!mounted) return;
      scaffoldMessengerKey.currentState?.showSnackBar(
        SnackBar(
          content: Text(stravaErrorToUserMessage(e)),
          backgroundColor: AppColors.error,
          duration: const Duration(seconds: 10),
        ),
      );
    }
  }

  /// Safety net per web: se per qualsiasi motivo l'URL contiene `?ticket=`
  /// (es. residuo da un vecchio redirect) tentiamo lo scambio e poi puliamo l'URL.
  /// Il flusso principale usa `connect2/start` server-side — questo non viene chiamato
  /// nel caso normale.
  Future<void> _resumeGarminWebOAuthIfNeeded() async {
    if (!kIsWeb || !mounted) return;
    var uid =
        FirebaseAuth.instance.currentUser?.uid ??
        ref.read(authNotifierProvider).user?.uid;
    if (uid == null) {
      for (var i = 0; i < 50; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 100));
        if (!mounted) return;
        uid =
            FirebaseAuth.instance.currentUser?.uid ??
            ref.read(authNotifierProvider).user?.uid;
        if (uid != null) break;
      }
    }
    if (uid == null) return;

    final garmin = ref.read(garminServiceProvider);
    try {
      final result = await garmin.completeGarminWebOAuthIfPresent(uid: uid);
      if (result == null || !mounted) return;

      if (result['success'] == true) {
        ref.invalidate(garminConnectedProvider);
        ref.invalidate(activitiesStreamProvider);
        ref.invalidate(dailyHealthStreamProvider);
        unawaited(
          ref
              .read(garminSyncNotifierProvider.notifier)
              .syncNow(uid: uid, trigger: 'settings_garmin_connect_web'),
        );
        scaffoldMessengerKey.currentState?.showSnackBar(
          const SnackBar(content: Text('✅ Garmin collegato.')),
        );
      }
      // Errori silenziosi: l'URL viene pulito comunque; il flusso principale
      // (connect2/start) non produce ?ticket= quindi questo ramo è quasi mai attivo.
    } catch (e, st) {
      debugPrint('Garmin web ticket cleanup: $e\n$st');
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangePlatformBrightness() {
    super.didChangePlatformBrightness();
    if (kIsWeb) _syncIosPwaChrome();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (kIsWeb) {
        unawaited(_resumeGarminWebOAuthIfNeeded());
        // Su iOS la PWA torna in primo piano DOPO che l'auth Garmin è avvenuta
        // in una tab Safari separata. L'exchange ha già scritto garmin_linked=true
        // su Firestore: forziamo un re-read del provider in modo che la UI si
        // aggiorni immediatamente senza aspettare il prossimo event Firestore.
        if (mounted) ref.invalidate(garminConnectedProvider);
      }
      // Quando l'app torna attiva (es. da Safari/Chrome), controlla link in sospeso
      AppLinks().getLatestLink().then((uri) {
        StravaOAuthCallback.instance.handleUri(uri);
        GarminOAuthCallback.instance.handleUri(uri);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(appRouterProvider);

    ref.listen<String?>(authNotifierProvider.select((s) => s.user?.uid), (
      prev,
      next,
    ) {
      if (next == null || next == prev) return;
      unawaited(
        ref
            .read(garminSyncNotifierProvider.notifier)
            .syncNow(uid: next, trigger: 'login'),
      );
    });

    ref.listen<AsyncValue<SyncBackfillStatus?>>(
      syncBackfillStatusStreamProvider,
      (prev, next) {
        final was = prev?.valueOrNull?.status;
        final now = next.valueOrNull?.status;
        if (now != 'completed') return;
        if (was != 'processing' && was != 'pending') return;
        final uid = ref.read(authNotifierProvider).user?.uid;
        if (uid == null) return;
        unawaited(
          ref
              .read(aggregationServiceProvider)
              .updateRolling10DaysAndBaseline(uid),
        );
      },
    );

    // Mostra errori auth anche quando si è navigati via (es. redirect a dashboard)
    ref.listen<String?>(authNotifierProvider.select((s) => s.error), (
      prev,
      next,
    ) {
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

    ref.listen(garminSyncNotifierProvider.select((s) => (s.error, s.trigger)), (
      prev,
      next,
    ) {
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
    });

    final themeMode = ref.watch(themeModeProvider);

    ref.listen<ThemeMode>(themeModeProvider, (prev, next) {
      if (!kIsWeb) return;
      WidgetsBinding.instance.addPostFrameCallback((_) => _syncIosPwaChrome());
    });

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
