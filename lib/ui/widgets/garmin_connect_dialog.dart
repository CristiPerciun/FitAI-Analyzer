import 'package:fitai_analyzer/app.dart';
import 'package:fitai_analyzer/services/garmin_service.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_web_auth_2/flutter_web_auth_2.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// URL embed Garmin SSO — callback intercettato da FlutterWebAuth2 su tutte le piattaforme native.
const _garminEmbedService = 'https://sso.garmin.com/sso/embed';

/// Dialog per collegare Garmin Connect.
///
/// ### Flusso unico per tutti i target:
/// 1. L'utente clicca "Apri login Garmin".
/// 2. **Web (kIsWeb)**: si apre un popup con la pagina di login Garmin.
///    Dopo il login, Garmin redirige il popup a `garmin_oauth_return.html?ticket=ST-…`;
///    la pagina manda il ticket via `postMessage` al parent **senza ricaricare l'app**,
///    e subito `POST /garmin/connect3/exchange-ticket` scambia il ticket col server.
/// 3. **Native** (iOS, Android, Windows, macOS, Linux): `FlutterWebAuth2` apre un
///    browser di sistema con `service=https://sso.garmin.com/sso/embed`.
///    Garmin redirige a `https://sso.garmin.com/sso/embed?ticket=ST-…` che viene
///    intercettato da FlutterWebAuth2 → ticket scambiato col server.
/// 4. Il server salva i token su Firebase; la risposta `success:true` chiude il dialog.
Future<bool?> showGarminConnectDialog(
  BuildContext context,
  WidgetRef ref, {
  required String uid,
}) async {
  return showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) {
      final submitting = <bool>[false];

      return StatefulBuilder(
        builder: (ctx, setDialogState) {
          Future<void> onConnect() async {
            if (submitting[0]) return;
            submitting[0] = true;
            setDialogState(() {});

            late Map<String, dynamic> result;
            try {
              if (kIsWeb) {
                // Web / PWA: popup + postMessage — nessun reload dell'app.
                result = await ref
                    .read(garminServiceProvider)
                    .connectViaGarminSsoWeb(uid: uid);
              } else {
                // Native: FlutterWebAuth2 intercetta il redirect a sso.garmin.com/sso/embed.
                final ssoUrl = GarminService.buildGarminWebSsoSigninUrl(
                  _garminEmbedService,
                );
                final callbackUrl = await FlutterWebAuth2.authenticate(
                  url: ssoUrl,
                  callbackUrlScheme: 'https',
                  options: const FlutterWebAuth2Options(
                    httpsHost: 'sso.garmin.com',
                    httpsPath: '/sso/embed',
                  ),
                );
                result = await ref
                    .read(garminServiceProvider)
                    .connect3ExchangeTicket(uid: uid, ticketOrUrl: callbackUrl);
              }
            } on Object catch (e) {
              result = {'success': false, 'message': 'Errore: $e'};
            } finally {
              submitting[0] = false;
              if (ctx.mounted) setDialogState(() {});
            }

            if (!ctx.mounted) return;

            if (result['success'] == true) {
              Navigator.of(ctx).pop(true);
            } else {
              final msg =
                  result['message']?.toString() ?? 'Errore sconosciuto.';
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
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  kIsWeb
                      ? "Si aprirà un popup con la pagina di login Garmin. "
                            'Accedi con le tue credenziali Garmin Connect e '
                            'la connessione avverrà automaticamente.'
                      : "Si aprirà il browser con la pagina di login Garmin. "
                            'Accedi con le tue credenziali Garmin Connect e '
                            "la connessione avverrà automaticamente.",
                  style: Theme.of(ctx).textTheme.bodyMedium,
                ),
                if (submitting[0]) ...[
                  const SizedBox(height: 20),
                  const Center(child: CircularProgressIndicator()),
                  const SizedBox(height: 8),
                  Center(
                    child: Text(
                      'Login in corso — attendi…',
                      style: Theme.of(ctx).textTheme.bodySmall,
                    ),
                  ),
                ],
              ],
            ),
            actions: [
              TextButton(
                onPressed: submitting[0]
                    ? null
                    : () => Navigator.of(ctx).pop(null),
                child: const Text('Annulla'),
              ),
              FilledButton(
                onPressed: submitting[0] ? null : onConnect,
                child: submitting[0]
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Apri login Garmin'),
              ),
            ],
          );
        },
      );
    },
  );
}
