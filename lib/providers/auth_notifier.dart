import 'package:firebase_auth/firebase_auth.dart';
import 'package:fitai_analyzer/providers/providers.dart';
import 'package:fitai_analyzer/utils/api_constants.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

class AuthState {
  static const _omit = Object();

  final User? user;
  final bool isLoading;
  final String? error;
  final String? currentService; // 'garmin' o 'myfitnesspal'

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

    try {
      if (FirebaseAuth.instance.currentUser == null) {
        await ref.read(authServiceProvider).signInAnonymously();
      }

      String authUrl;
      if (service == 'garmin') {
        final clientId = ApiConstants.garminClientId;
        if (clientId.isEmpty || clientId.startsWith('INSERISCI_QUI')) {
          throw StateError('Configura garminClientId in lib/utils/api_constants.dart');
        }
        authUrl = await ref.read(garminServiceProvider).getAuthorizationUrl(
              clientId: clientId,
              redirectUri: ApiConstants.garminRedirectUri,
            );
      } else if (service == 'myfitnesspal') {
        final clientId = ApiConstants.mfpClientId;
        if (clientId.isEmpty || clientId.startsWith('INSERISCI_QUI')) {
          throw StateError('Configura mfpClientId in lib/utils/api_constants.dart');
        }
        authUrl = ref.read(mfpServiceProvider).getAuthorizationUrl(
              clientId: clientId,
              redirectUri: ApiConstants.mfpRedirectUri,
            );
      } else {
        throw ArgumentError('Servizio non supportato: $service');
      }

      final uri = Uri.parse(authUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        throw StateError('Impossibile aprire: $authUrl');
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
