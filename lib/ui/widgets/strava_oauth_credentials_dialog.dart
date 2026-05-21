import 'package:fitai_analyzer/providers/auth_notifier.dart';
import 'package:fitai_analyzer/services/strava_oauth_credentials_service.dart';
import 'package:fitai_analyzer/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

Future<bool> showStravaOAuthCredentialsDialog(
  BuildContext context,
  WidgetRef ref,
) async {
  final uid = ref.read(authNotifierProvider).user?.uid;
  if (uid == null) return false;

  final service = ref.read(stravaOAuthCredentialsServiceProvider);
  final existing = await service.read(uid);
  if (!context.mounted) return false;

  final clientIdController = TextEditingController(
    text: existing?.clientId ?? '',
  );
  final clientSecretController = TextEditingController(
    text: existing?.clientSecret ?? '',
  );

  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => AlertDialog(
      title: const Text('Credenziali Strava'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Inserisci Client ID e Client Secret della tua app Strava. '
              'Devono appartenere alla stessa app configurata su strava.com/settings/api.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: clientIdController,
              decoration: const InputDecoration(
                labelText: 'Client ID',
                hintText: '123456',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
              autocorrect: false,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: clientSecretController,
              decoration: const InputDecoration(
                labelText: 'Client Secret',
                border: OutlineInputBorder(),
              ),
              obscureText: true,
              autocorrect: false,
            ),
            const SizedBox(height: 8),
            Text(
              'Per web/GitHub Pages il Callback Domain deve combaciare con il dominio '
              'della web app. Per app nativa usa il dominio del deep link configurato.',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppColors.textMuted),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: const Text('Annulla'),
        ),
        FilledButton(
          onPressed: () async {
            final clientId = clientIdController.text.trim();
            final clientSecret = clientSecretController.text.trim();
            if (!StravaOAuthCredentialsService.isValidClientId(clientId) ||
                clientSecret.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'Inserisci un Client ID numerico e un Client Secret Strava valido.',
                  ),
                ),
              );
              return;
            }
            await service.save(
              uid,
              clientId: clientId,
              clientSecret: clientSecret,
            );
            if (ctx.mounted) Navigator.of(ctx).pop(true);
          },
          child: const Text('Salva e continua'),
        ),
      ],
    ),
  );

  clientIdController.dispose();
  clientSecretController.dispose();
  return result ?? false;
}
