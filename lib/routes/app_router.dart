import 'package:fitai_analyzer/ui/auth/login_screen.dart';
import 'package:fitai_analyzer/ui/onboarding/onboarding_details_screen.dart';
import 'package:fitai_analyzer/ui/onboarding/onboarding_screen.dart';
import 'package:fitai_analyzer/ui/shell/main_shell_screen.dart';
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
      final isLoginRoute = state.uri.path == '/' || state.uri.path == '/login';

      if (!isLoggedIn && !isLoginRoute) return '/';
      if (isLoggedIn && isLoginRoute) return '/';
      return null;
    },
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const MainShellScreen(),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/onboarding',
        builder: (context, state) => const OnboardingScreen(),
        routes: [
          GoRoute(
            path: 'details',
            builder: (context, state) => const OnboardingDetailsScreen(),
          ),
        ],
      ),
    ],
  );
});
