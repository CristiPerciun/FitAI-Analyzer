import 'package:fitai_analyzer/ui/auth/auth_gateway.dart';
import 'package:fitai_analyzer/ui/onboarding/onboarding_screen.dart';
import 'package:fitai_analyzer/providers/auth_notifier.dart';
import 'package:fitai_analyzer/providers/route_transition_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Navigator root dell'app (push modali sopra AuthGateway / shell).
final rootNavigatorKey = GlobalKey<NavigatorState>();

final appRouterProvider = Provider<GoRouter>((ref) {
  final authRefresh = ValueNotifier(0);
  ref.listen(authNotifierProvider, (_, _) => authRefresh.value++);

  return GoRouter(
    navigatorKey: rootNavigatorKey,
    refreshListenable: authRefresh,
    // Disattiva il blur delle superfici glass durante le transizioni di rotta
    // (evita gli scatti da ri-raster del BackdropFilter su desktop).
    observers: [BlurTransitionObserver(ref)],
    redirect: (context, state) {
      final isLoggedIn = ref.read(authNotifierProvider).user != null;
      final path = state.uri.path;

      // Non loggato: solo '/' (AuthGateway mostra Login)
      if (!isLoggedIn && path != '/') return '/';
      // Loggato su route pubblica: va alla home (AuthGateway mostra MainShell)
      if (isLoggedIn && path == '/') return null;
      return null;
    },
    routes: [
      GoRoute(path: '/', builder: (context, state) => const AuthGateway()),
      GoRoute(
        path: '/onboarding',
        builder: (context, state) => const OnboardingScreen(),
      ),
    ],
  );
});
