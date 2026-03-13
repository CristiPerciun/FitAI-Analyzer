import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:fitai_analyzer/providers/providers.dart';
import 'package:fitai_analyzer/providers/strava_sync_status_notifier.dart';
import 'package:fitai_analyzer/services/aggregation_service.dart';
import 'package:fitai_analyzer/services/strava_service.dart';
import 'package:fitai_analyzer/utils/strava_error_messages.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AuthState {
  static const _omit = Object();

  final User? user;
  final bool isLoading;
  final String? error;
  final String? currentService; // 'strava' | ...

  AuthState({
    this.user,
    this.isLoading = false,
    this.error,
    this.currentService,
  });

  AuthState copyWith({
    User? user,
    bool? isLoading,
    Object? error = _omit,
    Object? currentService = _omit,
  }) {
    return AuthState(
      user: user ?? this.user,
      isLoading: isLoading ?? this.isLoading,
      error: identical(error, _omit) ? this.error : error as String?,
      currentService: identical(currentService, _omit)
          ? this.currentService
          : currentService as String?,
    );
  }
}

class AuthNotifier extends Notifier<AuthState> {
  @override
  AuthState build() => AuthState();

  /// Avvia OAuth per il servizio specificato.
  Future<void> startOAuth(
    String service, {
    void Function()? onSuccess,
  }) async {
    state = state.copyWith(isLoading: true, currentService: service, error: null);

    try {
      await _startOAuthImpl(service, onSuccess)
          .timeout(const Duration(minutes: 2), onTimeout: () {
        throw TimeoutException('Timeout connessione Strava (2 min)');
      });
    } catch (e) {
      final userMsg = service == 'strava'
          ? stravaErrorToUserMessage(e)
          : e.toString();
      state = state.copyWith(
        isLoading: false,
        error: userMsg,
        currentService: null,
      );
      rethrow;
    }
  }

  /// Esegue il flusso OAuth. Separato per il workaround Windows.
  Future<void> _startOAuthImpl(
    String service,
    void Function()? onSuccess,
  ) async {
    if (FirebaseAuth.instance.currentUser == null) {
      try {
        await ref.read(authServiceProvider).signInAnonymously();
        state = state.copyWith(user: FirebaseAuth.instance.currentUser);
      } catch (e) {
        throw StateError(
          'Login anonimo Firebase fallito. Errore originale: $e\n'
          'Verifica: google-services.json (Android), GoogleService-Info.plist (iOS), '
          'progetto Firebase con Auth anonima abilitata.',
        );
      }
    }

    if (service == 'strava') {
        final uid = FirebaseAuth.instance.currentUser?.uid;
        if (uid == null) {
          throw StateError('Utente non autenticato. Riprova.');
        }

        final statusNotifier = ref.read(stravaSyncStatusProvider.notifier);
        statusNotifier.reset();

        statusNotifier.setPhase(
          StravaSyncPhase.connecting,
          message: 'Connessione a Strava...',
        );

        List<StravaActivity> activities;
        try {
          statusNotifier.setPhase(
            StravaSyncPhase.connecting,
            message: 'Autorizzazione Strava...',
          );
          await ref.read(stravaServiceProvider).authenticate();
          statusNotifier.setPhase(
            StravaSyncPhase.connecting,
            message: 'Recupero attività da Strava...',
          );
          activities = await ref.read(stravaServiceProvider).getRecentActivities(days: 30);
        } catch (e) {
          // Token senza activity:read_all? Riprova con nuova autorizzazione
          final msg = e.toString();
          if (msg.contains('permessi') ||
              msg.contains('activity:read_permission') ||
              msg.contains('activity:read_all')) {
            statusNotifier.setPhase(
              StravaSyncPhase.connecting,
              message: 'Nuova autorizzazione Strava (permessi attività)...',
            );
            await ref.read(stravaServiceProvider).authenticate();
            activities = await ref.read(stravaServiceProvider).getRecentActivities(days: 30);
          } else {
            rethrow;
          }
        }

        statusNotifier.setPhase(
          StravaSyncPhase.connecting,
          message: 'Salvataggio su Firestore...',
        );
        try {
          await ref.read(stravaServiceProvider).saveToFirestore(uid, activities);
        } catch (e) {
          throw Exception('Errore salvataggio dati Strava: $e');
        }

        statusNotifier.setPhase(
          StravaSyncPhase.completed,
          message: 'Dati Strava salvati!',
        );

        // Aggiorna Livello 2 e 3 (rolling_10days + baseline)
        try {
          await ref.read(aggregationServiceProvider).updateRolling10DaysAndBaseline(uid);
        } catch (_) {
          // Non bloccare: aggregazione opzionale
        }

        state = state.copyWith(isLoading: false, currentService: null, error: null);
        onSuccess?.call();
        return;
    } else {
      throw ArgumentError('Servizio non supportato: $service');
    }
  }

  /// Esegue [fn] sul platform thread (workaround firebase_auth Windows).
  /// Deferisce di un frame per ridurre errori "non-platform thread".
  Future<void> _runOnPlatformThread(Future<void> Function() fn) async {
    final completer = Completer<void>();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        await fn();
        completer.complete();
      } catch (e) {
        completer.completeError(e);
      }
    });
    return completer.future;
  }

  Future<void> signInAnonymously() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await _runOnPlatformThread(() async {
        await ref.read(authServiceProvider).signInAnonymously();
        state = state.copyWith(
          user: FirebaseAuth.instance.currentUser,
          isLoading: false,
          error: null,
        );
      });
    } catch (e) {
      state = state.copyWith(
        error: e.toString(),
        isLoading: false,
      );
      rethrow;
    }
  }

  Future<void> signOut() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await _runOnPlatformThread(() async {
        await ref.read(authServiceProvider).signOut();
        state = AuthState();
      });
    } catch (e) {
      state = state.copyWith(error: e.toString(), isLoading: false);
      rethrow;
    }
  }
}

final authNotifierProvider =
    NotifierProvider<AuthNotifier, AuthState>(AuthNotifier.new);
