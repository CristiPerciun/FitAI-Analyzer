import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:fitai_analyzer/providers/providers.dart';
import 'package:fitai_analyzer/services/credential_storage_service.dart';
import 'package:fitai_analyzer/utils/platform_firestore_fix.dart';
import 'package:fitai_analyzer/providers/strava_sync_status_notifier.dart';
import 'package:fitai_analyzer/services/aggregation_service.dart';
import 'package:fitai_analyzer/services/garmin_service.dart';
import 'package:fitai_analyzer/services/strava_service.dart';
import 'package:fitai_analyzer/services/user_ai_settings_sync_service.dart';
import 'package:fitai_analyzer/utils/strava_error_messages.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Stream dello stato auth Firebase. Usato per aggiornare AuthNotifier al riavvio app.
/// Esposto per [AuthGateway]: finché è in loading, non mostrare il login (sessione in ripristino).
final authUserStreamProvider = StreamProvider<User?>((ref) {
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
  String? _aiSettingsHydratedUid;

  @override
  AuthState build() {
    // Ascolta authStateChanges: al riavvio app Firebase ripristina la sessione
    // in modo asincrono; senza questo listener AuthNotifier resterebbe con user=null
    ref.listen(authUserStreamProvider, (prev, next) {
      next.whenData((user) {
        if (state.user != user) {
          state = state.copyWith(user: user);
        }
        final uid = user?.uid;
        if (uid == null) {
          _aiSettingsHydratedUid = null;
          return;
        }
        if (_aiSettingsHydratedUid == uid) return;
        _aiSettingsHydratedUid = uid;
        unawaited(_pullAiSettingsFromCloud(uid));
      });
    });
    // Valore iniziale sincrono (può essere null se Firebase non ha ancora ripristinato)
    final user = ref.read(authServiceProvider).currentUser;
    return AuthState(user: user);
  }

  Future<void> _pullAiSettingsFromCloud(String uid) async {
    try {
      await ref.read(userAiSettingsSyncServiceProvider).pullFromCloud(uid);
      ref.invalidate(aiBackendSettingsProvider);
      invalidateAiRouting(ref);
    } catch (_) {}
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
      // Non rilanciare: evita Unhandled Exception; l’UI legge già state.error (es. dialog in Impostazioni).
    }
  }

  /// Esegue il flusso OAuth. Separato per il workaround Windows.
  Future<void> _startOAuthImpl(
    String service,
    void Function()? onSuccess,
  ) async {
    if (FirebaseAuth.instance.currentUser == null) {
      try {
        if (isWindows) {
          await _runOnPlatformThread(() async {
            await ref.read(authServiceProvider).signInAnonymously();
            state = state.copyWith(user: FirebaseAuth.instance.currentUser);
          });
        } else {
          await ref.read(authServiceProvider).signInAnonymously();
          state = state.copyWith(user: FirebaseAuth.instance.currentUser);
        }
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

        try {
          statusNotifier.setPhase(
            StravaSyncPhase.connecting,
            message: 'Autorizzazione Strava...',
          );
          await ref.read(stravaServiceProvider).authenticate();
        } catch (e) {
          if (e is StravaWebOAuthRedirectPending) {
            state = state.copyWith(
              isLoading: false,
              currentService: null,
              error: null,
            );
            return;
          }
          final msg = e.toString();
          if (msg.contains('permessi') ||
              msg.contains('activity:read_permission') ||
              msg.contains('activity:read_all')) {
            statusNotifier.setPhase(
              StravaSyncPhase.connecting,
              message: 'Nuova autorizzazione Strava (permessi attività)...',
            );
            try {
              await ref.read(stravaServiceProvider).authenticate();
            } on StravaWebOAuthRedirectPending {
              state = state.copyWith(
                isLoading: false,
                currentService: null,
                error: null,
              );
              return;
            }
          } else {
            rethrow;
          }
        }

        final tokens = await ref.read(stravaServiceProvider).getTokensForServer();
        if (tokens == null) {
          throw StateError('Token Strava non disponibili dopo OAuth.');
        }

        statusNotifier.setPhase(
          StravaSyncPhase.connecting,
          message: 'Invio token al server (backfill attività)...',
        );
        final reg = await ref.read(garminServiceProvider).registerStravaOnServer(
              uid: uid,
              accessToken: tokens.access,
              refreshToken: tokens.refresh,
              expiresAtMs: tokens.expiresAtMs,
            );
        if (reg['success'] != true) {
          throw Exception(reg['message']?.toString() ?? 'Registrazione Strava sul server fallita.');
        }

        statusNotifier.setPhase(
          StravaSyncPhase.completed,
          message: 'Strava collegato: sincronizzazione in background sul server.',
        );

        try {
          await ref.read(aggregationServiceProvider).updateRolling10DaysAndBaseline(uid);
        } catch (_) {}

        state = state.copyWith(isLoading: false, currentService: null, error: null);
        ref.invalidate(stravaConnectedProvider);
        onSuccess?.call();
        return;
    } else {
      throw ArgumentError('Servizio non supportato: $service');
    }
  }

  /// Dopo OAuth Strava su **web** (redirect + exchange via server), registra i token sul Pi/server.
  Future<void> syncStravaToServerAfterWebOAuth() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final tokens = await ref.read(stravaServiceProvider).getTokensForServer();
    if (tokens == null) return;

    final statusNotifier = ref.read(stravaSyncStatusProvider.notifier);
    statusNotifier.setPhase(
      StravaSyncPhase.connecting,
      message: 'Invio token al server (backfill attività)...',
    );

    final reg = await ref.read(garminServiceProvider).registerStravaOnServer(
          uid: uid,
          accessToken: tokens.access,
          refreshToken: tokens.refresh,
          expiresAtMs: tokens.expiresAtMs,
        );
    if (reg['success'] != true) {
      statusNotifier.reset();
      state = state.copyWith(
        error: reg['message']?.toString() ??
            'Registrazione Strava sul server fallita.',
      );
      return;
    }

    statusNotifier.setPhase(
      StravaSyncPhase.completed,
      message: 'Strava collegato: sincronizzazione in background sul server.',
    );

    try {
      await ref.read(aggregationServiceProvider).updateRolling10DaysAndBaseline(uid);
    } catch (_) {}

    ref.invalidate(stravaConnectedProvider);
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
  ///
  /// Su Windows `getIdToken(true)` aggiunge refresh lato SDK che alimenta il canale
  /// `id-token` e spesso logga ancora "non-platform thread" (bug plugin, flutterfire#11933).
  /// Qui usiamo solo la cache del token: meno rumore in debug; su mobile resta refresh forzato.
  Future<bool> verifyTokenAndSignOutIfInvalid(User user) async {
    try {
      await _runOnPlatformThread(() async {
        await user.getIdToken(!isWindows);
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
      if (isWindows) {
        await _runOnPlatformThread(() async {
          await ref.read(authServiceProvider).signInWithEmailAndPassword(
                creds.email,
                creds.password,
              );
          state = state.copyWith(user: FirebaseAuth.instance.currentUser);
        });
      } else {
        await ref.read(authServiceProvider).signInWithEmailAndPassword(
              creds.email,
              creds.password,
            );
        state = state.copyWith(user: FirebaseAuth.instance.currentUser);
      }
      return true;
    } catch (_) {
      await ref.read(credentialStorageServiceProvider).clearCredentials();
      return false;
    }
  }

  /// Re-auth e nuova password. Aggiorna le credenziali in secure storage se erano salvate.
  Future<void> updatePasswordWithReauth({
    required String currentPassword,
    required String newPassword,
  }) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await _runOnPlatformThread(() async {
        final user = FirebaseAuth.instance.currentUser;
        if (user == null) throw StateError('Utente non autenticato');
        final email = user.email;
        if (email == null || email.isEmpty) {
          throw StateError('Nessuna email associata all’account.');
        }
        final cred = EmailAuthProvider.credential(
          email: email,
          password: currentPassword,
        );
        await user.reauthenticateWithCredential(cred);
        await user.updatePassword(newPassword);
      });
      final user = FirebaseAuth.instance.currentUser;
      final creds =
          await ref.read(credentialStorageServiceProvider).getCredentials();
      if (creds != null && user?.email != null) {
        await ref.read(credentialStorageServiceProvider).saveCredentials(
              email: user!.email!,
              password: newPassword,
              rememberMe: true,
            );
      }
      state = state.copyWith(isLoading: false);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e is FirebaseAuthException
            ? _firebaseAuthExceptionMessage(e)
            : _authErrorToMessage(e),
      );
      rethrow;
    }
  }

  /// Invia email di verifica al nuovo indirizzo; il cambio è effettivo dopo il link (Firebase).
  Future<void> verifyBeforeUpdateUserEmail({
    required String currentPassword,
    required String newEmail,
  }) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await _runOnPlatformThread(() async {
        final user = FirebaseAuth.instance.currentUser;
        if (user == null) throw StateError('Utente non autenticato');
        final email = user.email;
        if (email == null || email.isEmpty) {
          throw StateError('Nessuna email associata.');
        }
        final cred = EmailAuthProvider.credential(
          email: email,
          password: currentPassword,
        );
        await user.reauthenticateWithCredential(cred);
        await user.verifyBeforeUpdateEmail(newEmail.trim());
      });
      state = state.copyWith(isLoading: false);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e is FirebaseAuthException
            ? _firebaseAuthExceptionMessage(e)
            : _authErrorToMessage(e),
      );
      rethrow;
    }
  }

  static String _firebaseAuthExceptionMessage(FirebaseAuthException e) {
    switch (e.code) {
      case 'wrong-password':
      case 'invalid-credential':
        return 'Password attuale non corretta.';
      case 'weak-password':
        return 'La nuova password è troppo debole (min. 6 caratteri).';
      case 'invalid-email':
        return 'Indirizzo email non valido.';
      case 'email-already-in-use':
        return 'Questa email è già usata da un altro account.';
      default:
        return e.message ?? e.code;
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
