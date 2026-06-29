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

/// Stato (immutabile) del dialog Garmin. Locale alla modale, gestito via
/// [ValueNotifier] invece che con `setState`.
class _GarminBridgeState {
  const _GarminBridgeState({
    this.priming = false,
    this.ready = false,
    this.error,
    this.submitting = false,
  });

  final bool priming;
  final bool ready;
  final String? error;
  final bool submitting;

  _GarminBridgeState copyWith({
    bool? priming,
    bool? ready,
    String? error,
    bool? submitting,
  }) {
    return _GarminBridgeState(
      priming: priming ?? this.priming,
      ready: ready ?? this.ready,
      error: error ?? this.error,
      submitting: submitting ?? this.submitting,
    );
  }
}

class _GarminConnectDialogBodyState
    extends ConsumerState<_GarminConnectDialogBody> {
  final ValueNotifier<_GarminBridgeState> _state =
      ValueNotifier<_GarminBridgeState>(const _GarminBridgeState());

  /// Su web usiamo SEMPRE il ponte `garmin_oauth_prepare.html`:
  /// è l'unico modo affidabile su iPhone/PWA e ci evita il doppio flusso popup → full-page.
  bool get _useWebKitBridge => kIsWeb;

  @override
  void initState() {
    super.initState();
    if (_useWebKitBridge) {
      _state.value = const _GarminBridgeState(priming: true);
      WidgetsBinding.instance.addPostFrameCallback((_) => _primeGarminBridge());
    } else {
      _state.value = const _GarminBridgeState(ready: true);
    }
  }

  @override
  void dispose() {
    _state.dispose();
    super.dispose();
  }

  Future<void> _primeGarminBridge() async {
    try {
      await ref.read(garminServiceProvider).primeGarminWebSsoBridge(
            uid: widget.uid,
      );
      if (!mounted) return;
      _state.value = const _GarminBridgeState(ready: true);
    } on Object catch (e) {
      if (!mounted) return;
      _state.value = _GarminBridgeState(error: e.toString());
    }
  }

  Future<void> _onConnect() async {
    if (_state.value.submitting) return;

    if (_useWebKitBridge) {
      if (!_state.value.ready || _state.value.error != null) return;
      _state.value = _state.value.copyWith(submitting: true);
      final apiBase = ref
          .read(garminServiceProvider)
          .lastResolvedServerBaseUrlForWebBridge;
      garmin_web.garminWebNavigateToGarminOAuthPreparePage(
        uid: widget.uid,
        apiBase: apiBase,
      );
      if (mounted) Navigator.of(context).pop(null);
      return;
    }

    _state.value = _state.value.copyWith(submitting: true);

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
      if (mounted) _state.value = _state.value.copyWith(submitting: false);
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
    return ValueListenableBuilder<_GarminBridgeState>(
      valueListenable: _state,
      builder: (context, s, _) {
        final bridgeLoading = _useWebKitBridge && (s.priming || !s.ready);
        final canTapConnect = !s.submitting &&
            (!_useWebKitBridge || (s.ready && s.error == null));

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
              if (s.error != null) ...[
                const SizedBox(height: 12),
                Text(
                  s.error!,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.error,
                      ),
                ),
              ],
              if (bridgeLoading || s.submitting) ...[
                const SizedBox(height: 20),
                const Center(child: CircularProgressIndicator()),
                const SizedBox(height: 8),
                Center(
                  child: Text(
                    s.priming
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
              onPressed:
                  s.submitting ? null : () => Navigator.of(context).pop(null),
              child: const Text('Annulla'),
            ),
            FilledButton(
              onPressed: canTapConnect ? _onConnect : null,
              child: s.submitting && !_useWebKitBridge
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
  }
}
