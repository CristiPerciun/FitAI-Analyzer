import 'package:firebase_auth/firebase_auth.dart';
import 'package:fitai_analyzer/providers/auth_notifier.dart';
import 'package:fitai_analyzer/providers/providers.dart';
import 'package:fitai_analyzer/providers/user_profile_notifier.dart';
import 'package:fitai_analyzer/ui/auth/login_screen.dart';
import 'package:fitai_analyzer/ui/launch/launch_screen.dart';
import 'package:fitai_analyzer/ui/onboarding/onboarding_screen.dart';
import 'package:fitai_analyzer/ui/shell/main_shell_screen.dart';
import 'package:fitai_analyzer/utils/boot_log.dart';
import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Gateway reattivo che decide cosa mostrare in base allo stato di Firebase Auth.
/// Usa authNotifier (non lo stream) per reagire subito al login (su Windows lo stream
/// fa polling ogni 5s e non aggiornerebbe subito).
///
/// Flusso:
/// 1. Errore o utente non trovato → LoginScreen
/// 2. Già loggato con email → verifica token → verifica profilo:
///    - Profilo assente (nuovo utente) → Onboarding
///    - Profilo presente → MainShell (home)
/// 3. Utente anonimo → sign out + LoginScreen (nessun onboarding senza account reale)
class AuthGateway extends ConsumerStatefulWidget {
  const AuthGateway({super.key});

  @override
  ConsumerState<AuthGateway> createState() => _AuthGatewayState();
}

class _AuthGatewayState extends ConsumerState<AuthGateway> {
  bool _authReady = false;
  String? _lastGatewayUi;

  void _traceGatewayUi(String label) {
    if (_lastGatewayUi == label) return;
    _lastGatewayUi = label;
    bootLog('AuthGateway: $label');
  }

  @override
  void initState() {
    super.initState();
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.windows) {
      bootLog('Windows: posticipo di 1 frame prima di leggere auth (workaround piattaforma)');
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          bootLog('Auth gateway: primo frame OK, auth utilizzabile');
          setState(() => _authReady = true);
        }
      });
    } else {
      _authReady = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_authReady) {
      _traceGatewayUi('Launch — attesa primo frame (Windows) o init');
      return const Scaffold(body: LaunchScreen());
    }
    final authState = ref.watch(authNotifierProvider);
    final user = authState.user;
    final authStream = ref.watch(authUserStreamProvider);

    // Evita "Login" per ~1s mentre Firebase ripristina la sessione (v. log Boot).
    if (user == null && authStream.isLoading) {
      _traceGatewayUi('Launch — attesa primo evento auth (ripristino sessione)');
      return const Scaffold(body: LaunchScreen());
    }

    if (user != null && user.isAnonymous) {
      _traceGatewayUi('Login — utente anonimo, sign-out in post-frame');
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(authNotifierProvider.notifier).signOut();
      });
      return const LoginScreen();
    }
    if (user != null && !user.isAnonymous) {
      _traceGatewayUi('VerifyUserGate — utente ${user.uid} (verifica token)');
      return _VerifyUserGate(user: user);
    }
    _traceGatewayUi('Login — nessuna sessione');
    return const LoginScreen();
  }
}

/// Verifica che il token sia ancora valido (utente non cancellato da Firebase).
/// Se invalido, esegue sign out e si torna al login.
class _VerifyUserGate extends ConsumerStatefulWidget {
  const _VerifyUserGate({required this.user});

  final User user;

  @override
  ConsumerState<_VerifyUserGate> createState() => _VerifyUserGateState();
}

class _VerifyUserGateState extends ConsumerState<_VerifyUserGate> {
  bool _verified = false;
  bool _isVerifying = true;
  String? _lastVerifyUi;

  void _traceVerifyUi(String label) {
    if (_lastVerifyUi == label) return;
    _lastVerifyUi = label;
    bootLog('VerifyUserGate: $label');
  }

  @override
  void initState() {
    super.initState();
    bootLog('VerifyUserGate: inizio verifica token (uid=${widget.user.uid})');
    _verify();
  }

  Future<void> _verify() async {
    final valid = await ref
        .read(authNotifierProvider.notifier)
        .verifyTokenAndSignOutIfInvalid(widget.user);
    if (!mounted) return;
    bootLog('VerifyUserGate: token ${valid ? "valido" : "non valido —→ login"}');
    setState(() {
      _isVerifying = false;
      _verified = valid;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isVerifying) {
      _traceVerifyUi('Launch — verifica token in corso');
      return const Scaffold(body: LaunchScreen());
    }
    if (!_verified) {
      _traceVerifyUi('Login — sessione non valida');
      return const LoginScreen();
    }
    _traceVerifyUi('LoggedInGate — caricamento profilo / home');
    return const _LoggedInGate();
  }
}

/// Controlla se il profilo esiste: se nuovo → Onboarding, altrimenti precarica il
/// pacchetto Home e apre MainShell (una sola UI di launch durante i caricamenti).
class _LoggedInGate extends ConsumerStatefulWidget {
  const _LoggedInGate();

  @override
  ConsumerState<_LoggedInGate> createState() => _LoggedInGateState();
}

class _LoggedInGateState extends ConsumerState<_LoggedInGate> {
  String? _lastLoggedUi;

  /// Riverpod non consente di aggiornare un provider in [initState]/durante il build.
  /// Fino al primo post-frame mostriamo Launch; poi [loadProfile] imposta `isLoading`.
  bool _profileKickoffPending = true;

  void _traceLoggedUi(String label) {
    if (_lastLoggedUi == label) return;
    _lastLoggedUi = label;
    bootLog('LoggedInGate: $label');
  }

  @override
  void initState() {
    super.initState();
    bootLog('LoggedInGate: loadProfile() schedulato dopo il primo frame (regola Riverpod)');
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(userProfileNotifierProvider.notifier).loadProfile();
      setState(() => _profileKickoffPending = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final profileState = ref.watch(userProfileNotifierProvider);
    final uid = ref.watch(authNotifierProvider).user?.uid;

    if (_profileKickoffPending) {
      _traceLoggedUi('Launch — attesa post-frame (prima di loadProfile, no flash Onboarding)');
      return const Scaffold(body: LaunchScreen());
    }

    if (profileState.isLoading) {
      _traceLoggedUi('Launch — profilo utente in caricamento');
      return const Scaffold(body: LaunchScreen());
    }

    if (uid == null || profileState.error != null) {
      _traceLoggedUi(
        'Login — uid assente o errore profilo (${profileState.error})',
      );
      return const LoginScreen();
    }

    if (profileState.profile == null) {
      _traceLoggedUi('Onboarding — profilo assente (nuovo utente)');
      return const OnboardingScreen();
    }

    final homePkg = ref.watch(longevityHomePackageProvider);
    // Durante un refresh Riverpod può avere isLoading=true ma hasValue=true: non
    // sostituire MainShell con Launch (altrimenti shell e Home si smontano di nuovo).
    if (homePkg.isLoading && !homePkg.hasValue) {
      _traceLoggedUi('Launch — precaricamento pacchetto Home (primo caricamento)');
      return const Scaffold(body: LaunchScreen());
    }

    if (homePkg.hasError) {
      _traceLoggedUi(
        'MainShell — pacchetto Home in errore (la Home mostrerà retry): ${homePkg.error}',
      );
    } else {
      _traceLoggedUi('MainShell — pacchetto Home pronto, apertura shell');
    }
    return const MainShellScreen();
  }
}
