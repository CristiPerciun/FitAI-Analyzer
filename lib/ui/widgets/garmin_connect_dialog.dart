import 'package:fitai_analyzer/app.dart';
import 'package:fitai_analyzer/services/garmin_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Dialog per collegare Garmin Connect (email + password).
/// Invia le credenziali al garmin-sync-server che valida su Garmin.
Future<bool?> showGarminConnectDialog(
  BuildContext context,
  WidgetRef ref, {
  required String uid,
}) async {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final formKey = GlobalKey<FormState>();

  return showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) {
      final submitting = <bool>[false];
      final lastConnectAttempt = <DateTime?>[null];
      return StatefulBuilder(
        builder: (ctx, setDialogState) {
          Future<void> onConnect() async {
            if (submitting[0]) return;
            if (!formKey.currentState!.validate()) return;

            final now = DateTime.now();
            final prev = lastConnectAttempt[0];
            if (prev != null &&
                now.difference(prev) < const Duration(seconds: 5)) {
              scaffoldMessengerKey.currentState?.showSnackBar(
                const SnackBar(
                  content: Text(
                    'Attendi qualche secondo tra un tentativo e l’altro.',
                  ),
                  duration: Duration(seconds: 3),
                ),
              );
              return;
            }
            lastConnectAttempt[0] = now;

            final email = emailController.text.trim();
            final password = passwordController.text;

            submitting[0] = true;
            setDialogState(() {});
            if (!ctx.mounted) return;
            showDialog<void>(
              context: ctx,
              barrierDismissible: false,
              builder: (c) => const Center(
                child: Card(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text('Connessione al server Garmin in corso...'),
                      ],
                    ),
                  ),
                ),
              ),
            );

            late Map<String, dynamic> result;
            try {
              result = await ref.read(garminServiceProvider).connect(
                    uid: uid,
                    email: email,
                    password: password,
                  );
            } on Object catch (e) {
              result = {
                'success': false,
                'message': 'Errore imprevisto: $e',
              };
            } finally {
              if (ctx.mounted) {
                Navigator.of(ctx).pop();
              }
              submitting[0] = false;
              if (ctx.mounted) {
                setDialogState(() {});
              }
            }

            if (!ctx.mounted) return;

            if (result['success'] == true) {
              Navigator.of(ctx).pop(true);
            } else {
              final msg = result['message']?.toString() ?? 'Errore sconosciuto';
              scaffoldMessengerKey.currentState?.showSnackBar(
                SnackBar(
                  content: Text('Garmin: $msg'),
                  backgroundColor: Theme.of(ctx).colorScheme.error,
                  duration: const Duration(seconds: 10),
                ),
              );
            }
          }

          return AlertDialog(
            title: const Text('Collega Garmin Connect'),
            content: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Inserisci le credenziali del tuo account Garmin Connect. '
                      'Il collegamento passa dal tuo server FitAI che contatta Garmin.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 20),
                    TextFormField(
                      controller: emailController,
                      enabled: !submitting[0],
                      decoration: const InputDecoration(
                        labelText: 'Email Garmin',
                        hintText: 'nome@email.com',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.emailAddress,
                      autocorrect: false,
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) {
                          return 'Inserisci l\'email';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: passwordController,
                      enabled: !submitting[0],
                      decoration: const InputDecoration(
                        labelText: 'Password',
                        border: OutlineInputBorder(),
                      ),
                      obscureText: true,
                      autocorrect: false,
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'Inserisci la password';
                        return null;
                      },
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: submitting[0] ? null : () => Navigator.of(ctx).pop(null),
                child: const Text('Annulla'),
              ),
              FilledButton(
                onPressed: submitting[0] ? null : () => onConnect(),
                child: submitting[0]
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Collega'),
              ),
            ],
          );
        },
      );
    },
  );
}
