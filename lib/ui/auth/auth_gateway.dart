import 'package:firebase_auth/firebase_auth.dart';
import 'package:fitai_analyzer/providers/auth_notifier.dart';
import 'package:fitai_analyzer/providers/user_profile_notifier.dart';
import 'package:fitai_analyzer/ui/auth/login_screen.dart';
import 'package:fitai_analyzer/ui/onboarding/onboarding_screen.dart';
import 'package:fitai_analyzer/ui/shell/main_shell_screen.dart';
import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Gateway reattivo che decide cosa mostrare in base allo stato di Firebase Auth.
///
/// Flusso:
/// 1. Mai fatto login → LoginScreen (registrati o accedi)
/// 2. Già loggato con email (Firebase persistence o Ricordami) → verifica profilo:
///    - Profilo assente → Onboarding
///    - Profilo presente → MainShell (home)
/// 3. Utente anonimo → sign out + LoginScreen (nessun onboarding senza account reale)
class AuthGateway extends ConsumerStatefulWidget {
  const AuthGateway({super.key});

  @override
  ConsumerState<AuthGateway> createState() => _AuthGatewayState();
}

class _AuthGatewayState extends ConsumerState<AuthGateway> {
  bool _authReady = false;

  @override
  void initState() {
    super.initState();
    // Su Windows, ritarda l'accesso ad authStateChanges per ridurre errori
    // "non-platform thread" del plugin firebase_auth.
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.windows) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _authReady = true);
      });
    } else {
      _authReady = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_authReady) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        final user = snapshot.data;
        // Solo utenti con account reale (email/password) bypassano il login.
        // Gli anonimi: sign out e mostra LoginScreen (nessun onboarding senza login).
        if (user != null && user.isAnonymous) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            ref.read(authNotifierProvider.notifier).signOut();
          });
          return const LoginScreen();
        }
        if (user != null && !user.isAnonymous) {
          return _VerifyUserGate(user: user);
        }
        return const LoginScreen();
      },
    );
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

  @override
  void initState() {
    super.initState();
    _verify();
  }

  Future<void> _verify() async {
    final valid = await ref
        .read(authNotifierProvider.notifier)
        .verifyTokenAndSignOutIfInvalid(widget.user);
    if (!mounted) return;
    setState(() {
      _isVerifying = false;
      _verified = valid;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isVerifying || !_verified) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    return const _LoggedInGate();
  }
}

/// Controlla se il profilo esiste: se nuovo → Onboarding, altrimenti MainShell.
class _LoggedInGate extends ConsumerStatefulWidget {
  const _LoggedInGate();

  @override
  ConsumerState<_LoggedInGate> createState() => _LoggedInGateState();
}

class _LoggedInGateState extends ConsumerState<_LoggedInGate> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(userProfileNotifierProvider.notifier).loadProfile();
    });
  }

  @override
  Widget build(BuildContext context) {
    final profileState = ref.watch(userProfileNotifierProvider);

    if (profileState.isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (profileState.profile == null) {
      return const OnboardingScreen();
    }

    return const MainShellScreen();
  }
}
