// ignore_for_file: deprecated_member_use, avoid_web_libraries_in_flutter

import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:html' as html;

void _oauthWebLog(String message) {
  developer.log(message, name: 'GarminOAuthWeb');
}

/// Chiave condivisa tra `garmin_oauth_return.html` (popup) e finestra principale (PWA).
/// Su iOS `postMessage` verso l’opener è talvolta inaffidabile; il polling su localStorage no.
const String _kGarminOAuthPopupStorageKey = 'garmin_oauth_popup_result_v1';

String _garminOAuthPopupWindowFeatures() {
  final ua = html.window.navigator.userAgent.toLowerCase();
  final isIos =
      ua.contains('iphone') ||
      ua.contains('ipad') ||
      ua.contains('ipod') ||
      (ua.contains('macintosh') && ua.contains('mobile'));
  if (isIos) {
    // Safari iOS ignora quasi sempre width/height; `popup=yes` è l’unico hint utile.
    return 'popup=yes,scrollbars=yes';
  }
  return 'popup=yes,width=440,height=720,scrollbars=yes,resizable=yes,toolbar=no';
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

/// Apre Garmin SSO in un popup e attende l'esito via `postMessage`.
///
/// La pagina `garmin_oauth_return.html` invia
/// `{type:'garmin_oauth_result', ticket_or_url: '<href>', error?: ...}`.
///
/// Ritorna:
/// - `{'ticket_or_url': '...'}` se OK (href completo dopo redirect Garmin),
/// - `{'error': '...'}` se Garmin ha passato `error` in query,
/// - `null` se popup bloccata, chiusa senza completare, o timeout.
Future<Map<String, dynamic>?> garminWebOAuthViaPopup(
  String ssoUrl, {
  Duration timeout = const Duration(minutes: 5),
}) async {
  final completer = Completer<Map<String, dynamic>?>();
  html.EventListener? messageListener;
  Timer? closedPollTimer;
  Timer? storagePollTimer;
  var consecutivePopupClosed = 0;

  _oauthWebLog('garminWebOAuthViaPopup: inizio timeout=${timeout.inMinutes}m');
  _oauthWebLog('garminWebOAuthViaPopup: ssoUrl=$ssoUrl');

  void clearStalePopupResult() {
    try {
      html.window.localStorage.remove(_kGarminOAuthPopupStorageKey);
    } on Object {
      // Private mode / storage bloccato
    }
  }

  void cleanup() {
    if (messageListener != null) {
      html.window.removeEventListener('message', messageListener!);
      messageListener = null;
    }
    closedPollTimer?.cancel();
    closedPollTimer = null;
    storagePollTimer?.cancel();
    storagePollTimer = null;
  }

  void finishFromPayload(Map<String, dynamic> data, String via) {
    if (completer.isCompleted) return;
    if (data['type'] != 'garmin_oauth_result') return;
    _oauthWebLog(
      'garminWebOAuthViaPopup: esito via $via keys=${data.keys.join(",")}',
    );
    cleanup();
    clearStalePopupResult();
    final err = (data['error'] as String?)?.trim();
    if (err != null && err.isNotEmpty) {
      completer.complete({'error': err});
      return;
    }
    final ticketOrUrl = (data['ticket_or_url'] as String?)?.trim();
    if (ticketOrUrl != null && ticketOrUrl.isNotEmpty) {
      completer.complete({'ticket_or_url': ticketOrUrl});
      return;
    }
    final ticket = (data['ticket'] as String?) ?? '';
    if (ticket.isNotEmpty) {
      final synthetic = garminWebOAuthReturnPageUri().replace(
        queryParameters: {'ticket': ticket},
      );
      completer.complete({'ticket_or_url': synthetic.toString()});
      return;
    }
    completer.complete(null);
  }

  clearStalePopupResult();

  messageListener = (html.Event event) {
    if (event is! html.MessageEvent) return;
    final me = event;
    if (completer.isCompleted) return;
    if (me.origin != html.window.location.origin) {
      _oauthWebLog(
        'garminWebOAuthViaPopup: origin ignorato=${me.origin} atteso=${html.window.location.origin}',
      );
      return;
    }
    try {
      dynamic payload = me.data;
      Map<String, dynamic>? data;
      if (payload is String) {
        if (payload.isEmpty) return;
        data = jsonDecode(payload) as Map<String, dynamic>;
      } else if (payload is Map) {
        data = Map<String, dynamic>.from(payload);
      } else {
        return;
      }
      finishFromPayload(data, 'postMessage');
    } on Object catch (e) {
      final preview = me.data?.toString() ?? '';
      final short =
          preview.length > 120 ? '${preview.substring(0, 120)}…' : preview;
      _oauthWebLog(
        'garminWebOAuthViaPopup: message ignorato o JSON non valido: $e '
        'origin=${me.origin} preview=$short',
      );
    }
  };

  html.window.addEventListener('message', messageListener!);

  final features = _garminOAuthPopupWindowFeatures();
  _oauthWebLog('garminWebOAuthViaPopup: window features=$features');

  // ignore: unnecessary_cast
  final popup =
      html.window.open(
            ssoUrl,
            'garmin_oauth',
            features,
          )
          as html.WindowBase?;

  if (popup == null) {
    _oauthWebLog('garminWebOAuthViaPopup: window.open ha restituito null (popup bloccato?)');
    cleanup();
    return null;
  }
  _oauthWebLog(
    'garminWebOAuthViaPopup: popup aperta (postMessage + poll localStorage)',
  );

  storagePollTimer = Timer.periodic(const Duration(milliseconds: 320), (_) {
    if (completer.isCompleted) return;
    String? raw;
    try {
      raw = html.window.localStorage[_kGarminOAuthPopupStorageKey];
    } on Object {
      return;
    }
    if (raw == null || raw.isEmpty) return;
    try {
      final data = jsonDecode(raw) as Map<String, dynamic>;
      finishFromPayload(data, 'localStorage');
    } on Object catch (e) {
      _oauthWebLog('garminWebOAuthViaPopup: parse localStorage fallito: $e');
    }
  });

  closedPollTimer = Timer.periodic(const Duration(milliseconds: 400), (_) {
    if (completer.isCompleted) return;
    if (popup.closed == true) {
      consecutivePopupClosed++;
      // Durante i redirect Garmin `closed` può essere flaky; richiedi più letture consecutive.
      if (consecutivePopupClosed >= 8) {
        _oauthWebLog(
          'garminWebOAuthViaPopup: popup risulta chiusa (debounce), stop',
        );
        cleanup();
        completer.complete(null);
      }
    } else {
      consecutivePopupClosed = 0;
    }
  });

  try {
    return await completer.future.timeout(
      timeout,
      onTimeout: () {
        _oauthWebLog('garminWebOAuthViaPopup: timeout dopo ${timeout.inMinutes}m');
        cleanup();
        clearStalePopupResult();
        return null;
      },
    );
  } catch (e) {
    _oauthWebLog('garminWebOAuthViaPopup: eccezione $e');
    cleanup();
    clearStalePopupResult();
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
            _garminOAuthPopupWindowFeatures(),
          )
          as html.WindowBase?;
  final ok = popup != null;
  _oauthWebLog('garminWebOpenPopup: opened=$ok');
  return ok;
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
