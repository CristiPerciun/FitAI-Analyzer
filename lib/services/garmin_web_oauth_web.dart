// ignore_for_file: deprecated_member_use, avoid_web_libraries_in_flutter

import 'dart:async';
import 'dart:convert';
import 'dart:html' as html;

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
    if (completer.isCompleted) return;
    try {
      final raw = event.data?.toString() ?? '';
      if (raw.isEmpty) return;
      final data = jsonDecode(raw) as Map<String, dynamic>;
      if (data['type'] != 'garmin_oauth_result') return;
      cleanup();
      final ticket = (data['ticket'] as String?) ?? '';
      completer.complete(ticket.isEmpty ? null : ticket);
    } on Object {
      // messaggio non nostro, ignorato
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
    // Popup bloccato dal browser
    cleanup();
    return null;
  }

  // Monitora chiusura manuale del popup
  pollTimer = Timer.periodic(const Duration(milliseconds: 750), (timer) {
    if (!completer.isCompleted && (popup.closed == true)) {
      cleanup();
      completer.complete(null);
    }
  });

  try {
    return await completer.future.timeout(
      timeout,
      onTimeout: () {
        cleanup();
        return null;
      },
    );
  } catch (e) {
    cleanup();
    return null;
  }
}

void garminWebAssignLocation(String url) {
  html.window.location.assign(url);
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
