import 'package:fitai_analyzer/features/auth/auth_selection_screen.dart';
import 'package:fitai_analyzer/features/auth/login_screen.dart';
import 'package:fitai_analyzer/features/dashboard/dashboard_screen.dart';
import 'package:fitai_analyzer/providers/auth_notifier.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final authRefresh = ValueNotifier(0);
  ref.listen(authNotifierProvider, (_, __) => authRefresh.value++);

  return GoRouter(
    refreshListenable: authRefresh,
    redirect: (context, state) {
      final isLoggedIn = ref.read(authNotifierProvider).user != null;
      final isLoginRoute = state.uri.path == '/' || state.uri.path == '/login';

      if (!isLoggedIn && !isLoginRoute) return '/';
      if (isLoggedIn && isLoginRoute) return '/dashboard';
      return null;
    },
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const AuthSelectionScreen(),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/dashboard',
        builder: (context, state) => const DashboardScreen(),
      ),
    ],
  );
});
