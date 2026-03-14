import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:fitai_analyzer/providers/providers.dart';
import 'package:fitai_analyzer/services/credential_storage_service.dart';
import 'package:fitai_analyzer/providers/strava_sync_status_notifier.dart';
import 'package:fitai_analyzer/services/aggregation_service.dart';
import 'package:fitai_analyzer/services/strava_service.dart';
import 'package:fitai_analyzer/utils/strava_error_messages.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Stream dello stato auth Firebase. Usato per aggiornare AuthNotifier al riavvio app.
final _authUserStreamProvider = StreamProvider<User?>((ref) {
  return ref.watch(authServiceProvider).authStateChanges;
});

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
  AuthState build() {
    // Ascolta authStateChanges: al riavvio app Firebase ripristina la sessione
    // in modo asincrono; senza questo listener AuthNotifier resterebbe con user=null
    ref.listen(_authUserStreamProvider, (prev, next) {
      next.whenData((user) {
        if (state.user != user) {
          state = state.copyWith(user: user);
        }
      });
    });
    // Valore iniziale sincrono (può essere null se Firebase non ha ancora ripristinato)
    final user = ref.read(authServiceProvider).currentUser;
    return AuthState(user: user);
  }

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
        ref.invalidate(stravaConnectedProvider);
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
        await ref.read(credentialStorageServiceProvider).clearCredentials();
        state = AuthState();
      });
    } catch (e) {
      state = state.copyWith(error: e.toString(), isLoading: false);
      rethrow;
    }
  }

  /// Verifica se il token è ancora valido (es. utente non cancellato da Firebase).
  /// Se invalido, esegue sign out. Esegue sempre sul platform thread (Windows).
  Future<bool> verifyTokenAndSignOutIfInvalid(User user) async {
    try {
      await _runOnPlatformThread(() async {
        await user.getIdToken(true);
      });
      return true;
    } catch (_) {
      await signOut();
      return false;
    }
  }

  /// Login con email e password. Se [rememberMe] è true, salva le credenziali per auto-login.
  Future<void> signInWithEmailAndPassword({
    required String email,
    required String password,
    required bool rememberMe,
  }) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await _runOnPlatformThread(() async {
        await ref.read(authServiceProvider).signInWithEmailAndPassword(
              email.trim(),
              password,
            );
        await ref.read(credentialStorageServiceProvider).saveCredentials(
              email: email,
              password: password,
              rememberMe: rememberMe,
            );
        state = state.copyWith(
          user: FirebaseAuth.instance.currentUser,
          isLoading: false,
          error: null,
        );
      });
    } catch (e) {
      state = state.copyWith(
        error: _authErrorToMessage(e),
        isLoading: false,
      );
      rethrow;
    }
  }

  /// Registrazione con email e password. Se [rememberMe] è true, salva le credenziali.
  Future<void> createAccountWithEmailAndPassword({
    required String email,
    required String password,
    required bool rememberMe,
  }) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await _runOnPlatformThread(() async {
        await ref.read(authServiceProvider).createUserWithEmailAndPassword(
              email.trim(),
              password,
            );
        await ref.read(credentialStorageServiceProvider).saveCredentials(
              email: email,
              password: password,
              rememberMe: rememberMe,
            );
        state = state.copyWith(
          user: FirebaseAuth.instance.currentUser,
          isLoading: false,
          error: null,
        );
      });
    } catch (e) {
      state = state.copyWith(
        error: _authErrorToMessage(e),
        isLoading: false,
      );
      rethrow;
    }
  }

  /// Auto-login con credenziali salvate. Usato all'avvio se "Ricordami" era attivo.
  Future<bool> tryAutoLoginWithSavedCredentials() async {
    final creds = await ref.read(credentialStorageServiceProvider).getCredentials();
    if (creds == null) return false;

    try {
      await ref.read(authServiceProvider).signInWithEmailAndPassword(
            creds.email,
            creds.password,
          );
      state = state.copyWith(user: FirebaseAuth.instance.currentUser);
      return true;
    } catch (_) {
      await ref.read(credentialStorageServiceProvider).clearCredentials();
      return false;
    }
  }

  static String _authErrorToMessage(Object e) {
    final msg = e.toString().toLowerCase();
    if (msg.contains('invalid-credential') || msg.contains('invalid_credential')) {
      return 'Email o password non corretti.';
    }
    if (msg.contains('user-not-found')) return 'Utente non trovato.';
    if (msg.contains('wrong-password')) return 'Password errata.';
    if (msg.contains('email-already-in-use')) return 'Email già registrata.';
    if (msg.contains('weak-password')) return 'Password troppo debole (min 6 caratteri).';
    if (msg.contains('invalid-email')) return 'Email non valida.';
    return e.toString();
  }
}

final authNotifierProvider =
    NotifierProvider<AuthNotifier, AuthState>(AuthNotifier.new);
