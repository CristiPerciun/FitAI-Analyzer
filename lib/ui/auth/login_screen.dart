import 'package:fitai_analyzer/providers/auth_notifier.dart';
import 'package:fitai_analyzer/ui/widgets/error_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class LoginScreen extends ConsumerWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authNotifierProvider);

    ref.listen(authNotifierProvider, (prev, next) {
      if (next.error != null &&
          next.error!.isNotEmpty &&
          next.error != prev?.error &&
          context.mounted) {
        showErrorDialog(context, next.error!);
      }
    });

    return Scaffold(
      body: Center(
        child: authState.isLoading
            ? const CircularProgressIndicator()
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Hero(
                    tag: 'logo',
                    child: Text(
                      'FitAI Analyzer',
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                  ),
                  const SizedBox(height: 32),
                  ElevatedButton(
                    onPressed: () => ref
                        .read(authNotifierProvider.notifier)
                        .signInAnonymously(),
                    child: const Text('Login Anonimo'),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
      ),
    );
  }
}
