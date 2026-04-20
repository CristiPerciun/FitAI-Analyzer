// ignore_for_file: deprecated_member_use, avoid_web_libraries_in_flutter

import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:html' as html;

void _oauthWebLog(String message) {
  developer.log(message, name: 'GarminOAuthWeb');
}

Uri? garminWebCurrentUri() {
  try {
    final href = html.window.location.href;
    if (href.isEmpty) return null;
    return Uri.parse(href);
  } on Object {
    return null;
  }
}

/// URL assoluto della pagina statica `web/garmin_oauth_return.html`.
Uri garminWebOAuthReturnPageUri() {
  final loc = Uri.parse(html.window.location.href);
  final base = loc.replace(query: '', fragment: '');
  final dir = base.resolve('.');
  var p = dir.path;
  if (!p.endsWith('/')) p = '$p/';
  return Uri(
    scheme: dir.scheme,
    host: dir.host,
    port: dir.hasPort ? dir.port : null,
    path: '${p}garmin_oauth_return.html',
  );
}

/// URL assoluto della pagina statica `web/garmin_oauth_start.html`.
Uri garminWebOAuthStartPageUri() {
  final loc = Uri.parse(html.window.location.href);
  final base = loc.replace(query: '', fragment: '');
  final dir = base.resolve('.');
  var p = dir.path;
  if (!p.endsWith('/')) p = '$p/';
  return Uri(
    scheme: dir.scheme,
    host: dir.host,
    port: dir.hasPort ? dir.port : null,
    path: '${p}garmin_oauth_start.html',
  );
}

/// Apre Garmin SSO in un popup e attende il ticket via `postMessage`.
///
/// La pagina `garmin_oauth_return.html` riceve il redirect da Garmin e chiama
/// `window.opener.postMessage({type:'garmin_oauth_result', ticket:'ST-...'}, origin)`.
/// Questa funzione risolve con il ticket grezzo (es. `ST-abc`) oppure `null` se
/// l'utente chiude il popup senza completare il login o scatta il timeout.
Future<String?> garminWebOAuthViaPopup(
  String ssoUrl, {
  Duration timeout = const Duration(minutes: 5),
}) async {
  final completer = Completer<String?>();
  html.EventListener? listener;
  Timer? pollTimer;

  _oauthWebLog('garminWebOAuthViaPopup: inizio timeout=${timeout.inMinutes}m');
  _oauthWebLog('garminWebOAuthViaPopup: ssoUrl=$ssoUrl');

  void cleanup() {
    if (listener != null) {
      html.window.removeEventListener('message', listener!);
      listener = null;
    }
    pollTimer?.cancel();
    pollTimer = null;
  }

  listener = (html.Event event) {
    if (event is! html.MessageEvent) return;
    final me = event;
    if (completer.isCompleted) return;
    try {
      final raw = me.data?.toString() ?? '';
      if (raw.isEmpty) return;
      final data = jsonDecode(raw) as Map<String, dynamic>;
      if (data['type'] != 'garmin_oauth_result') return;
      _oauthWebLog(
        'garminWebOAuthViaPopup: postMessage ricevuto origin=${me.origin} '
        'ticketLen=${(data['ticket'] as String?)?.length ?? 0}',
      );
      cleanup();
      final ticket = (data['ticket'] as String?) ?? '';
      completer.complete(ticket.isEmpty ? null : ticket);
    } on Object catch (e) {
      final raw = me.data?.toString() ?? '';
      final preview = raw.length > 120 ? '${raw.substring(0, 120)}…' : raw;
      _oauthWebLog(
        'garminWebOAuthViaPopup: message ignorato o JSON non valido: $e '
        'origin=${me.origin} preview=$preview',
      );
    }
  };

  html.window.addEventListener('message', listener!);

  // javascript window.open() returns null at runtime if the popup is blocked,
  // even though dart:html types it as non-nullable.
  // ignore: unnecessary_cast
  final popup =
      html.window.open(
            ssoUrl,
            'garmin_oauth',
            'width=560,height=720,scrollbars=yes,toolbar=no,menubar=no,location=no',
          )
          as html.WindowBase?;

  if (popup == null) {
    _oauthWebLog('garminWebOAuthViaPopup: window.open ha restituito null (popup bloccato?)');
    // Popup bloccato dal browser
    cleanup();
    return null;
  }
  _oauthWebLog('garminWebOAuthViaPopup: popup aperta, in ascolto postMessage');

  // Monitora chiusura manuale del popup
  pollTimer = Timer.periodic(const Duration(milliseconds: 750), (timer) {
    if (!completer.isCompleted && (popup.closed == true)) {
      _oauthWebLog('garminWebOAuthViaPopup: popup chiusa dall utente');
      cleanup();
      completer.complete(null);
    }
  });

  try {
    return await completer.future.timeout(
      timeout,
      onTimeout: () {
        _oauthWebLog('garminWebOAuthViaPopup: timeout dopo ${timeout.inMinutes}m');
        cleanup();
        return null;
      },
    );
  } catch (e) {
    _oauthWebLog('garminWebOAuthViaPopup: eccezione $e');
    cleanup();
    return null;
  }
}

bool garminWebOpenPopup(String url) {
  _oauthWebLog('garminWebOpenPopup: url=$url');
  // ignore: unnecessary_cast
  final popup =
      html.window.open(
            url,
            'garmin_oauth',
            'width=560,height=720,scrollbars=yes,toolbar=no,menubar=no,location=no',
          )
          as html.WindowBase?;
  final ok = popup != null;
  _oauthWebLog('garminWebOpenPopup: opened=$ok');
  return ok;
}

void garminWebAssignLocation(String url) {
  html.window.location.assign(url);
}

/// Ritorna `true` se il browser è Safari su iOS (iPhone/iPad/iPod).
///
/// Su iOS PWA (standalone), `window.open()` apre una finestra Safari separata
/// (processo distinto): `postMessage` e `window.close()` non funzionano
/// cross-process. Questa funzione serve a scegliere la navigazione full-page
/// invece del popup.
bool garminWebIsIos() {
  final ua = html.window.navigator.userAgent.toLowerCase();
  return ua.contains('iphone') || ua.contains('ipad') || ua.contains('ipod');
}

void garminWebReplaceCleanUrl(Uri clean) {
  html.window.history.replaceState(null, '', clean.toString());
}

void garminWebSessionSet(String key, String value) {
  html.window.sessionStorage[key] = value;
}

String? garminWebSessionGet(String key) {
  return html.window.sessionStorage[key];
}

void garminWebSessionRemove(String key) {
  html.window.sessionStorage.remove(key);
}
