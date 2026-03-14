import 'package:fitai_analyzer/ui/auth/auth_gateway.dart';
import 'package:fitai_analyzer/ui/onboarding/onboarding_screen.dart';
import 'package:fitai_analyzer/providers/auth_notifier.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final authRefresh = ValueNotifier(0);
  ref.listen(authNotifierProvider, (_, _) => authRefresh.value++);

  return GoRouter(
    refreshListenable: authRefresh,
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
      GoRoute(
        path: '/',
        builder: (context, state) => const AuthGateway(),
      ),
      GoRoute(
        path: '/onboarding',
        builder: (context, state) => const OnboardingScreen(),
      ),
    ],
  );
});
