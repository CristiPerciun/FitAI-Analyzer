import 'package:fitai_analyzer/services/garmin_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Dialog per collegare Mi Fitness (Xiaomi/Huami, servizio non ufficiale).
Future<bool?> showMiFitnessConnectDialog(
  BuildContext context,
  WidgetRef ref, {
  required String uid,
}) {
  return showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => _MiFitnessConnectDialogBody(uid: uid),
  );
}

class _MiFitnessConnectDialogBody extends ConsumerStatefulWidget {
  const _MiFitnessConnectDialogBody({required this.uid});

  final String uid;

  @override
  ConsumerState<_MiFitnessConnectDialogBody> createState() =>
      _MiFitnessConnectDialogBodyState();
}

class _MiFitnessConnectDialogBodyState
    extends ConsumerState<_MiFitnessConnectDialogBody> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _obscure = true;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_loading) return;
    final email = _email.text.trim();
    final pw = _password.text;
    if (email.isEmpty || pw.isEmpty) {
      setState(() => _error = 'Inserisci email e password.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    final r = await ref.read(garminServiceProvider).connectMiFitness(
          uid: widget.uid,
          email: email,
          password: pw,
          region: 'eu',
        );
    if (!mounted) return;
    if (r['success'] == true) {
      _password.clear();
      Navigator.of(context).pop(true);
      return;
    }
    setState(() {
      _loading = false;
      _error = r['message']?.toString() ?? 'Connessione non riuscita.';
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      title: const Text('Mi Fitness (beta)'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Account Xiaomi usato con Mi Fitness. Il collegamento usa per default '
              'la regione Europa (Huami DE / Zepp EU). Le credenziali vengono inviate '
              'una sola volta al tuo server in HTTPS; non vengono salvate in chiaro '
              'nel cloud. Servizio non ufficiale: potrebbe smettere di funzionare.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              autocorrect: false,
              decoration: const InputDecoration(
                labelText: 'Email',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _password,
              obscureText: _obscure,
              decoration: InputDecoration(
                labelText: 'Password',
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: Icon(_obscure ? Icons.visibility : Icons.visibility_off),
                  onPressed: () => setState(() => _obscure = !_obscure),
                ),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(
                _error!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _loading ? null : () => Navigator.of(context).pop(false),
          child: const Text('Annulla'),
        ),
        FilledButton(
          onPressed: _loading ? null : _submit,
          child: _loading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Collega'),
        ),
      ],
    );
  }
}
