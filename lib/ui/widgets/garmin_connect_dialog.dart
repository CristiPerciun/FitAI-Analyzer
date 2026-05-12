import 'package:fitai_analyzer/app.dart';
import 'package:fitai_analyzer/services/garmin_service.dart';
import 'package:fitai_analyzer/services/garmin_web_oauth_stub.dart'
    if (dart.library.html) 'package:fitai_analyzer/services/garmin_web_oauth_web.dart'
    as garmin_web;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_web_auth_2/flutter_web_auth_2.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// URL embed Garmin SSO — callback intercettato da FlutterWebAuth2 su tutte le piattaforme native.
const _garminEmbedService = 'https://sso.garmin.com/sso/embed';

/// Dialog per collegare Garmin Connect.
Future<bool?> showGarminConnectDialog(
  BuildContext context,
  WidgetRef ref, {
  required String uid,
}) {
  return showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => _GarminConnectDialogBody(uid: uid),
  );
}

class _GarminConnectDialogBody extends ConsumerStatefulWidget {
  const _GarminConnectDialogBody({required this.uid});

  final String uid;

  @override
  ConsumerState<_GarminConnectDialogBody> createState() =>
      _GarminConnectDialogBodyState();
}

class _GarminConnectDialogBodyState
    extends ConsumerState<_GarminConnectDialogBody> {
  final _submitting = <bool>[false];
  bool _bridgePriming = false;
  bool _bridgeReady = false;
  String? _bridgeError;

  bool get _useWebKitBridge =>
      kIsWeb && garmin_web.garminWebPreferGarminSsoFullPage();

  @override
  void initState() {
    super.initState();
    if (_useWebKitBridge) {
      _bridgePriming = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _primeGarminBridge());
    } else {
      _bridgeReady = true;
    }
  }

  Future<void> _primeGarminBridge() async {
    try {
      await ref.read(garminServiceProvider).primeGarminWebSsoBridge(
            uid: widget.uid,
      );
      if (!mounted) return;
      setState(() {
        _bridgePriming = false;
        _bridgeReady = true;
        _bridgeError = null;
      });
    } on Object catch (e) {
      if (!mounted) return;
      setState(() {
        _bridgePriming = false;
        _bridgeReady = false;
        _bridgeError = e.toString();
      });
    }
  }

  Future<void> _onConnect() async {
    if (_submitting[0]) return;

    if (_useWebKitBridge) {
      if (!_bridgeReady || _bridgeError != null) return;
      _submitting[0] = true;
      if (mounted) setState(() {});
      garmin_web.garminWebNavigateToGarminOAuthPreparePage();
      if (mounted) Navigator.of(context).pop(null);
      return;
    }

    _submitting[0] = true;
    if (mounted) setState(() {});

    late Map<String, dynamic> result;
    try {
      final garmin = ref.read(garminServiceProvider);
      if (kIsWeb) {
        result = await garmin.connectViaGarminSsoWeb(uid: widget.uid);
      } else {
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
            .connect3ExchangeTicket(uid: widget.uid, ticketOrUrl: callbackUrl);
      }
    } on Object catch (e) {
      result = {'success': false, 'message': 'Errore: $e'};
    } finally {
      _submitting[0] = false;
      if (mounted) setState(() {});
    }

    if (!mounted) return;

    if (result['success'] == true) {
      Navigator.of(context).pop(true);
    } else if (result['web_redirect'] == true) {
      Navigator.of(context).pop(null);
    } else {
      final msg = result['message']?.toString() ?? 'Errore sconosciuto.';
      scaffoldMessengerKey.currentState?.showSnackBar(
        SnackBar(
          content: Text('Garmin: $msg'),
          backgroundColor: Theme.of(context).colorScheme.error,
          duration: const Duration(seconds: 10),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bridgeLoading = _useWebKitBridge && (_bridgePriming || !_bridgeReady);
    final canTapConnect = !_submitting[0] &&
        (!_useWebKitBridge || (_bridgeReady && _bridgeError == null));

    return AlertDialog(
      title: const Text('Collega Garmin Connect'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            kIsWeb
                ? 'Su telefono, PWA installata o localhost il browser apre una pagina intermedia, '
                      'poi il login Garmin nella stessa scheda. '
                      'Su altri desktop può aprirsi una seconda finestra.'
                : "Si aprirà il browser con la pagina di login Garmin. "
                      'Accedi con le tue credenziali Garmin Connect e '
                      "la connessione avverrà automaticamente.",
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          if (_bridgeError != null) ...[
            const SizedBox(height: 12),
            Text(
              _bridgeError!,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.error,
                  ),
            ),
          ],
          if (bridgeLoading || _submitting[0]) ...[
            const SizedBox(height: 20),
            const Center(child: CircularProgressIndicator()),
            const SizedBox(height: 8),
            Center(
              child: Text(
                _bridgePriming
                    ? 'Preparazione connessione…'
                    : 'Login in corso — attendi…',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: _submitting[0] ? null : () => Navigator.of(context).pop(null),
          child: const Text('Annulla'),
        ),
        FilledButton(
          onPressed: canTapConnect ? _onConnect : null,
          child: _submitting[0] && !_useWebKitBridge
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
  }
}
