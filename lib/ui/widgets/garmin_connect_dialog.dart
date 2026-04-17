import 'package:fitai_analyzer/app.dart';
import 'package:fitai_analyzer/services/garmin_service.dart';
import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;
import 'package:flutter_web_auth_2/flutter_web_auth_2.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// URL embed Garmin SSO — callback intercettato da FlutterWebAuth2 su tutte le piattaforme native.
const _garminEmbedService = 'https://sso.garmin.com/sso/embed';

/// Dialog per collegare Garmin Connect.
///
/// ### Flusso Garmin per target:
/// 1. L'utente clicca "Apri login Garmin".
/// 2. **Web desktop / Android**: si apre un popup con la pagina di login Garmin.
///    Dopo il login, Garmin redirige il popup a `garmin_oauth_return.html?ticket=ST-…`;
///    la pagina manda il ticket via `postMessage` al parent **senza ricaricare l'app**,
///    e subito `POST /garmin/connect3/exchange-ticket` scambia il ticket col server.
/// 3. **Web iOS / PWA iPhone**: login diretto nel dialog via server (`connect2/*`).
///    Evita il ritorno browser -> PWA che su iPhone non e' affidabile.
/// 4. **Native** (iOS, Android, Windows, macOS, Linux): `FlutterWebAuth2` apre un
///    browser di sistema con `service=https://sso.garmin.com/sso/embed`.
///    Garmin redirige a `https://sso.garmin.com/sso/embed?ticket=ST-…` che viene
///    intercettato da FlutterWebAuth2 → ticket scambiato col server.
/// 5. Il server salva i token su Firebase; la risposta `success:true` chiude il dialog.
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
      final obscurePassword = <bool>[true];
      final useDirectIosWebLogin =
          kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;
      var email = '';
      var password = '';
      var mfaCode = '';
      var loginSessionId = '';
      var mfaRequired = false;
      String? formError;

      return StatefulBuilder(
        builder: (ctx, setDialogState) {
          Future<void> onConnect() async {
            if (submitting[0]) return;
            if (useDirectIosWebLogin) {
              if (!mfaRequired) {
                if (email.trim().isEmpty || password.isEmpty) {
                  setDialogState(() {
                    formError = 'Inserisci email e password Garmin.';
                  });
                  return;
                }
              } else if (mfaCode.trim().isEmpty) {
                setDialogState(() {
                  formError = 'Inserisci il codice di verifica Garmin.';
                });
                return;
              }
            }

            FocusScope.of(ctx).unfocus();
            submitting[0] = true;
            setDialogState(() {
              formError = null;
            });

            late Map<String, dynamic> result;
            try {
              final garmin = ref.read(garminServiceProvider);
              if (useDirectIosWebLogin) {
                if (!mfaRequired) {
                  result = await garmin.connect2Start(
                    uid: uid,
                    email: email.trim(),
                    password: password,
                  );
                  if (result['mfaRequired'] == true) {
                    final sessionId = result['loginSessionId']?.toString() ?? '';
                    if (sessionId.isEmpty) {
                      result = {
                        'success': false,
                        'message':
                            'Garmin ha richiesto la verifica, ma il server non ha restituito la sessione MFA.',
                      };
                    } else {
                      loginSessionId = sessionId;
                      mfaRequired = true;
                      submitting[0] = false;
                      setDialogState(() {
                        formError = null;
                      });
                      return;
                    }
                  }
                } else {
                  result = await garmin.connect2VerifyMfa(
                    uid: uid,
                    loginSessionId: loginSessionId,
                    mfaCode: mfaCode.trim(),
                  );
                }
              } else if (kIsWeb) {
                // Web desktop / Android: popup + postMessage — nessun reload dell'app.
                result = await garmin.connectViaGarminSsoWeb(uid: uid);
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
            } else if (result['ios_redirect'] == true) {
              // Fallback legacy: la pagina sta navigando verso Garmin SSO.
              Navigator.of(ctx).pop(null);
            } else {
              final msg =
                  result['message']?.toString() ?? 'Errore sconosciuto.';
              if (useDirectIosWebLogin) {
                setDialogState(() {
                  formError = msg;
                });
              } else {
                scaffoldMessengerKey.currentState?.showSnackBar(
                  SnackBar(
                    content: Text('Garmin: $msg'),
                    backgroundColor: Theme.of(ctx).colorScheme.error,
                    duration: const Duration(seconds: 10),
                  ),
                );
              }
            }
          }

          return AlertDialog(
            title: const Text('Collega Garmin Connect'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  useDirectIosWebLogin
                      ? 'Su iPhone il login Garmin avviene direttamente qui '
                            "nell'app, senza aprire Safari o Chrome. "
                            'Se Garmin richiede MFA, ti verrà chiesto il codice '
                            'nel passaggio successivo.'
                      : kIsWeb
                      ? "Si aprirà un popup con la pagina di login Garmin. "
                            'Accedi con le tue credenziali Garmin Connect e '
                            'la connessione avverrà automaticamente.'
                      : "Si aprirà il browser con la pagina di login Garmin. "
                            'Accedi con le tue credenziali Garmin Connect e '
                            "la connessione avverrà automaticamente.",
                  style: Theme.of(ctx).textTheme.bodyMedium,
                ),
                if (useDirectIosWebLogin) ...[
                  const SizedBox(height: 16),
                  if (!mfaRequired) ...[
                    TextField(
                      enabled: !submitting[0],
                      keyboardType: TextInputType.emailAddress,
                      autofillHints: const [AutofillHints.username],
                      decoration: const InputDecoration(
                        labelText: 'Email Garmin',
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (value) => email = value,
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      enabled: !submitting[0],
                      obscureText: obscurePassword[0],
                      autofillHints: const [AutofillHints.password],
                      decoration: InputDecoration(
                        labelText: 'Password Garmin',
                        border: const OutlineInputBorder(),
                        suffixIcon: IconButton(
                          onPressed: submitting[0]
                              ? null
                              : () => setDialogState(() {
                                  obscurePassword[0] = !obscurePassword[0];
                                }),
                          icon: Icon(
                            obscurePassword[0]
                                ? Icons.visibility_off
                                : Icons.visibility,
                          ),
                        ),
                      ),
                      onChanged: (value) => password = value,
                    ),
                  ] else ...[
                    Text(
                      'Garmin richiede un codice di verifica per completare il collegamento.',
                      style: Theme.of(ctx).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      enabled: !submitting[0],
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Codice MFA',
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (value) => mfaCode = value,
                    ),
                  ],
                  if (formError != null && formError!.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(
                      formError!,
                      style: TextStyle(
                        color: Theme.of(ctx).colorScheme.error,
                      ),
                    ),
                  ],
                ],
                if (submitting[0]) ...[
                  const SizedBox(height: 20),
                  const Center(child: CircularProgressIndicator()),
                  const SizedBox(height: 8),
                  Center(
                    child: Text(
                      mfaRequired
                          ? 'Verifica Garmin in corso...'
                          : 'Login in corso — attendi…',
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
                    : Text(
                        useDirectIosWebLogin
                            ? (mfaRequired
                                  ? 'Verifica codice'
                                  : 'Collega Garmin')
                            : 'Apri login Garmin',
                      ),
              ),
            ],
          );
        },
      );
    },
  );
}
