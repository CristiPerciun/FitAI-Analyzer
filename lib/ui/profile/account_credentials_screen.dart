import 'package:fitai_analyzer/providers/auth_notifier.dart';
import 'package:fitai_analyzer/ui/widgets/error_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Modifica email (con verifica Firebase) e/o password.
class AccountCredentialsScreen extends ConsumerStatefulWidget {
  const AccountCredentialsScreen({super.key});

  @override
  ConsumerState<AccountCredentialsScreen> createState() =>
      _AccountCredentialsScreenState();
}

class _AccountCredentialsScreenState
    extends ConsumerState<AccountCredentialsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _currentPasswordController = TextEditingController();
  final _newEmailController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newEmailController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final currentPw = _currentPasswordController.text;
    final newEmail = _newEmailController.text.trim();
    final newPw = _newPasswordController.text;
    final confirmPw = _confirmPasswordController.text;

    final wantEmail = newEmail.isNotEmpty;
    final wantPassword = newPw.isNotEmpty || confirmPw.isNotEmpty;

    final currentEmail =
        ref.read(authNotifierProvider).user?.email?.toLowerCase();
    if (wantEmail && currentEmail != null && newEmail.toLowerCase() == currentEmail) {
      showErrorDialog(context, 'La nuova email è uguale a quella attuale.');
      return;
    }

    if (!wantEmail && !wantPassword) {
      showErrorDialog(
        context,
        'Inserisci una nuova email e/o una nuova password.',
      );
      return;
    }

    if (wantPassword) {
      if (newPw.length < 6) {
        showErrorDialog(context, 'La nuova password deve avere almeno 6 caratteri.');
        return;
      }
      if (newPw != confirmPw) {
        showErrorDialog(context, 'Le password non coincidono.');
        return;
      }
    }

    final notifier = ref.read(authNotifierProvider.notifier);

    try {
      if (wantEmail) {
        await notifier.verifyBeforeUpdateUserEmail(
          currentPassword: currentPw,
          newEmail: newEmail,
        );
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Controlla la casella della nuova email per confermare il cambio indirizzo.',
            ),
            duration: Duration(seconds: 6),
          ),
        );
      }

      if (wantPassword) {
        await notifier.updatePasswordWithReauth(
          currentPassword: currentPw,
          newPassword: newPw,
        );
        if (!mounted) return;
        _newPasswordController.clear();
        _confirmPasswordController.clear();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Password aggiornata.')),
        );
      }

      if (mounted && wantEmail && !wantPassword) {
        _newEmailController.clear();
      }
    } catch (_) {
      // Errore già mostrato tramite ref.listen su [authNotifierProvider].
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authNotifierProvider);
    final email = auth.user?.email ?? '—';

    ref.listen(authNotifierProvider, (prev, next) {
      if (next.error != null &&
          next.error!.isNotEmpty &&
          next.error != prev?.error &&
          context.mounted) {
        showErrorDialog(context, next.error!);
      }
    });

    return Scaffold(
      appBar: AppBar(title: const Text('Dati di accesso')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text(
              'Account',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              email,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'Per sicurezza, inserisci la password attuale prima di modificare email o password.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 24),
            TextFormField(
              controller: _currentPasswordController,
              decoration: const InputDecoration(
                labelText: 'Password attuale',
                border: OutlineInputBorder(),
              ),
              obscureText: true,
              validator: (v) {
                if (v == null || v.isEmpty) return 'Obbligatoria';
                return null;
              },
            ),
            const SizedBox(height: 28),
            Text(
              'Nuova email (opzionale)',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _newEmailController,
              decoration: const InputDecoration(
                labelText: 'Nuovo indirizzo email',
                hintText: 'Lasciare vuoto se non cambi',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 8),
            Text(
              'Riceverai un link di verifica: l’email dell’account si aggiorna solo dopo la conferma.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 28),
            Text(
              'Nuova password (opzionale)',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _newPasswordController,
              decoration: const InputDecoration(
                labelText: 'Nuova password',
                border: OutlineInputBorder(),
              ),
              obscureText: true,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _confirmPasswordController,
              decoration: const InputDecoration(
                labelText: 'Conferma nuova password',
                border: OutlineInputBorder(),
              ),
              obscureText: true,
            ),
            const SizedBox(height: 32),
            FilledButton(
              onPressed: auth.isLoading ? null : _submit,
              child: auth.isLoading
                  ? const SizedBox(
                      height: 22,
                      width: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Salva modifiche'),
            ),
          ],
        ),
      ),
    );
  }
}
