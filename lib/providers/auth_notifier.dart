import 'package:firebase_auth/firebase_auth.dart';
import 'package:fitai_analyzer/providers/data_sync_notifier.dart';
import 'package:fitai_analyzer/providers/health_sync_status_notifier.dart';
import 'package:fitai_analyzer/providers/providers.dart';
import 'package:fitai_analyzer/utils/api_constants.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

class AuthState {
  static const _omit = Object();

  final User? user;
  final bool isLoading;
  final String? error;
  final String? currentService; // 'garmin' | 'health' | 'demo'

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

  Future<void> startOAuth(String service, {void Function()? onSuccess}) async {
    state = state.copyWith(isLoading: true, currentService: service, error: null);
    if (service != ApiConstants.healthServiceName) {
      ref.read(healthSyncStatusProvider.notifier).reset();
    }

    try {
      if (FirebaseAuth.instance.currentUser == null) {
        await ref.read(authServiceProvider).signInAnonymously();
      }

      if (service == ApiConstants.healthServiceName) {
        await _runHealthSyncWithPhases(onSuccess);
        return;
      }

      if (service == 'garmin') {
        final clientId = ApiConstants.garminClientId;
        if (clientId.isEmpty || clientId.startsWith('INSERISCI_QUI')) {
          throw StateError('Configura garminClientId in lib/utils/api_constants.dart');
        }
        final authUrl = await ref.read(garminServiceProvider).getAuthorizationUrl(
              clientId: clientId,
              redirectUri: ApiConstants.garminRedirectUri,
            );
        final uri = Uri.parse(authUrl);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        } else {
          throw StateError('Impossibile aprire: $authUrl');
        }
      } else {
        throw ArgumentError('Servizio non supportato: $service');
      }

      state = state.copyWith(isLoading: false, currentService: null);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
        currentService: null,
      );
      rethrow;
    }
  }

  Future<void> _runHealthSyncWithPhases(void Function()? onSuccess) async {
    final statusNotifier = ref.read(healthSyncStatusProvider.notifier);
    statusNotifier.reset();

    try {
      statusNotifier.setPhase(
        HealthSyncPhase.configuring,
        message: 'Configurazione plugin Health...',
      );
      await ref.read(healthServiceProvider).configure();

      statusNotifier.setPhase(
        HealthSyncPhase.requestingPermissions,
        message: 'Richiesta permessi a Apple Health...',
      );
      final granted = await ref.read(healthServiceProvider).requestPermissions();

      statusNotifier.setPhase(
        HealthSyncPhase.permissionsResult,
        message: granted ? 'Permessi concessi' : 'Permessi negati',
        rawResponse: {'granted': granted},
      );
      if (!granted) {
        throw StateError('Autorizzazione Health non concessa');
      }

      statusNotifier.setPhase(
        HealthSyncPhase.fetchingData,
        message: 'Chiamata a getHealthDataFromTypes...',
      );
      final (rawJson, processed) =
          await ref.read(healthServiceProvider).fetchDataWithRaw();

      statusNotifier.setPhase(
        HealthSyncPhase.dataReceived,
        message: 'Risposta ricevuta (${rawJson.length} punti raw)',
        rawResponse: rawJson,
      );

      statusNotifier.setPhase(
        HealthSyncPhase.savingToFirestore,
        message: 'Salvataggio su Firestore...',
      );
      await ref.read(dataSyncNotifierProvider.notifier).saveHealthData(processed);

      statusNotifier.setPhase(
        HealthSyncPhase.complete,
        message: 'Sync completato',
      );
      state = state.copyWith(isLoading: false, currentService: null);
      onSuccess?.call();
    } catch (e) {
      statusNotifier.setError(e.toString());
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
        currentService: null,
      );
      rethrow;
    }
  }

  /// Simula il flusso Health su Windows: login + sync dati demo.
  /// Stesso comportamento del bottone Health su iPhone.
  Future<void> startDemoHealth({void Function()? onSuccess}) async {
    state = state.copyWith(isLoading: true, currentService: 'demo', error: null);
    ref.read(healthSyncStatusProvider.notifier).reset();

    try {
      if (FirebaseAuth.instance.currentUser == null) {
        await ref.read(authServiceProvider).signInAnonymously();
      }

      await ref.read(dataSyncNotifierProvider.notifier).syncHealthWithDemo();

      state = state.copyWith(isLoading: false, currentService: null);
      onSuccess?.call();
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
        currentService: null,
      );
      rethrow;
    }
  }

  Future<void> signInAnonymously() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await ref.read(authServiceProvider).signInAnonymously();
      state = state.copyWith(
        user: FirebaseAuth.instance.currentUser,
        isLoading: false,
        error: null,
      );
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
      await ref.read(authServiceProvider).signOut();
      state = AuthState();
    } catch (e) {
      state = state.copyWith(error: e.toString(), isLoading: false);
      rethrow;
    }
  }
}

final authNotifierProvider =
    NotifierProvider<AuthNotifier, AuthState>(AuthNotifier.new);
