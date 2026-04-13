import 'package:fitai_analyzer/providers/auth_notifier.dart';
import 'package:fitai_analyzer/ui/launch/launch_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _rememberMe = true;
  bool _isRegisterMode = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final email = _emailController.text.trim();
    final password = _passwordController.text;

    try {
      if (_isRegisterMode) {
        await ref.read(authNotifierProvider.notifier).createAccountWithEmailAndPassword(
              email: email,
              password: password,
              rememberMe: _rememberMe,
            );
      } else {
        await ref.read(authNotifierProvider.notifier).signInWithEmailAndPassword(
              email: email,
              password: password,
              rememberMe: _rememberMe,
            );
      }
    } catch (_) {
      // Errore già mostrato via state.error
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authNotifierProvider);

    if (authState.isLoading) {
      return const Scaffold(body: LaunchScreen());
    }

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 48),
                Hero(
                  tag: 'logo',
                  child: Text(
                    'FitAI Analyzer',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 48),
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    hintText: 'esempio@email.com',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.email_outlined),
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Inserisci l\'email';
                    if (!v.contains('@') || !v.contains('.')) return 'Email non valida';
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _passwordController,
                  obscureText: true,
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _submit(),
                  decoration: const InputDecoration(
                    labelText: 'Password',
                    hintText: 'Minimo 6 caratteri',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.lock_outline),
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Inserisci la password';
                    if (v.length < 6) return 'Minimo 6 caratteri';
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                CheckboxListTile(
                  value: _rememberMe,
                  onChanged: (v) => setState(() => _rememberMe = v ?? true),
                  title: Text(
                    'Ricordami',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  subtitle: Text(
                    'Salva email e password per accesso automatico',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: EdgeInsets.zero,
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: _submit,
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: Text(_isRegisterMode ? 'Registrati' : 'Accedi'),
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () => setState(() => _isRegisterMode = !_isRegisterMode),
                  child: Text(
                    _isRegisterMode
                        ? 'Hai già un account? Accedi'
                        : 'Non hai un account? Registrati',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
