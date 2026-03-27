import 'package:fitai_analyzer/app.dart';
import 'package:fitai_analyzer/services/garmin_oauth_callback.dart';
import 'package:fitai_analyzer/services/garmin_service.dart';
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;
import 'package:flutter_web_auth_2/flutter_web_auth_2.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

const _garminMobileCallbackUrl = 'myhealthsync://garmin/callback';

String _buildGarminMobileBrowserLoginUrl(String loginUrl) {
  final uri = Uri.parse(loginUrl);
  final query = Map<String, String>.from(uri.queryParameters);
  query['service'] = _garminMobileCallbackUrl;
  query['source'] = _garminMobileCallbackUrl;
  query['redirectAfterAccountLoginUrl'] = _garminMobileCallbackUrl;
  query['redirectAfterAccountCreationUrl'] = _garminMobileCallbackUrl;
  return uri.replace(queryParameters: query).toString();
}

bool _shouldUseGarminBrowserFallback(String message) {
  final m = message.toLowerCase();
  return m.contains('429') ||
      m.contains('too many requests') ||
      m.contains('sso.garmin.com') ||
      m.contains('/sso/signin');
}

/// Dialog principale per collegare Garmin Connect.
/// 1) prova login server-side diretto (`connect2`)
/// 2) se Garmin rate-limita il login automatico, apre il browser e cattura il ticket
/// 3) scambia il ticket sul server e salva il token
Future<bool?> showGarminConnectDialog(
  BuildContext context,
  WidgetRef ref, {
  required String uid,
}) async {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final mfaController = TextEditingController();
  final formKey = GlobalKey<FormState>();

  return showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) {
      final submitting = <bool>[false];
      final awaitingMfa = <bool>[false];
      final loginSessionId = <String?>[null];
      final lastConnectAttempt = <DateTime?>[null];
      return StatefulBuilder(
        builder: (ctx, setDialogState) {
          Future<Map<String, dynamic>> runBrowserFallback(
            String email,
            String loginUrl,
          ) async {
            if (kIsWeb) {
              return {
                'success': false,
                'message':
                    'Login Garmin via browser automatico non supportato sul web.',
              };
            }
            if (defaultTargetPlatform == TargetPlatform.iOS) {
              final waitFuture = GarminOAuthCallback.instance.waitForCallback();
              final launched = await launchUrl(
                Uri.parse(_buildGarminMobileBrowserLoginUrl(loginUrl)),
                mode: LaunchMode.externalApplication,
              );
              if (!launched) {
                return {
                  'success': false,
                  'message': 'Impossibile aprire Garmin in Safari.',
                };
              }
              final ticketOrUrl = await waitFuture;
              return ref
                  .read(garminServiceProvider)
                  .connect3ExchangeTicket(
                    uid: uid,
                    ticketOrUrl: ticketOrUrl,
                    email: email,
                  );
            }
            final result = await FlutterWebAuth2.authenticate(
              url: loginUrl,
              callbackUrlScheme: 'https',
              options: const FlutterWebAuth2Options(
                httpsHost: 'sso.garmin.com',
                httpsPath: '/sso/embed',
              ),
            );
            return ref
                .read(garminServiceProvider)
                .connect3ExchangeTicket(
                  uid: uid,
                  ticketOrUrl: result,
                  email: email,
                );
          }

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
              if (awaitingMfa[0]) {
                result = await ref
                    .read(garminServiceProvider)
                    .connect2VerifyMfa(
                      uid: uid,
                      loginSessionId: loginSessionId[0] ?? '',
                      mfaCode: mfaController.text,
                    );
              } else {
                result = await ref
                    .read(garminServiceProvider)
                    .connect2Start(uid: uid, email: email, password: password);
                final msg = result['message']?.toString() ?? '';
                final loginUrl = result['loginUrl']?.toString();
                if (result['success'] != true &&
                    result['mfaRequired'] != true &&
                    loginUrl != null &&
                    loginUrl.isNotEmpty &&
                    _shouldUseGarminBrowserFallback(msg)) {
                  result = await runBrowserFallback(email, loginUrl);
                }
              }
            } on Object catch (e) {
              result = {'success': false, 'message': 'Errore imprevisto: $e'};
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
            } else if (result['mfaRequired'] == true &&
                result['loginSessionId'] is String) {
              awaitingMfa[0] = true;
              loginSessionId[0] = result['loginSessionId'] as String;
              setDialogState(() {});
              scaffoldMessengerKey.currentState?.showSnackBar(
                SnackBar(
                  content: Text(
                    result['message']?.toString() ??
                        'Garmin richiede un codice MFA.',
                  ),
                  duration: const Duration(seconds: 8),
                ),
              );
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
            title: Text(
              awaitingMfa[0]
                  ? 'Collega Garmin Connect - MFA'
                  : 'Collega Garmin Connect',
            ),
            content: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      awaitingMfa[0]
                          ? 'Inserisci il codice MFA richiesto da Garmin per completare il collegamento.'
                          : 'Inserisci le credenziali Garmin. L\'app prova prima il login server-side; se Garmin risponde con il link SSO del fallback, apre quel link e cattura automaticamente il ticket finale.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 20),
                    if (!awaitingMfa[0]) ...[
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
                          if (v == null || v.isEmpty) {
                            return 'Inserisci la password';
                          }
                          return null;
                        },
                      ),
                    ] else ...[
                      TextFormField(
                        controller: mfaController,
                        enabled: !submitting[0],
                        decoration: const InputDecoration(
                          labelText: 'Codice MFA',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
                        autocorrect: false,
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) {
                            return 'Inserisci il codice MFA';
                          }
                          return null;
                        },
                      ),
                    ],
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: submitting[0]
                    ? null
                    : () => Navigator.of(ctx).pop(null),
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
                    : Text(awaitingMfa[0] ? 'Verifica MFA' : 'Collega'),
              ),
            ],
          );
        },
      );
    },
  );
}
