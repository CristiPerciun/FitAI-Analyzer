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

bool _navigatorStandaloneApplePwa() {
  try {
    // Proprietà WebKit non esposta su `Navigator` in dart:html.
    final dynamic nav = html.window.navigator;
    final Object? st = nav.standalone;
    return st == true;
  } on Object {
    return false;
  }
}

/// Su iPhone/iPad (e PWA installata) `window.open` + SSO Garmin spesso finisce in un contesto
/// con **storage partizionato** rispetto alla finestra principale: `postMessage` e `localStorage`
/// non raggiungono la PWA e l'utente resta sulla pagina Garmin. Il flusso **full-page** con
/// `prepare` (`state` + `gx_api` nel callback) evita l'opener e completa l'exchange in
/// `garmin_oauth_return.html` nella stessa scheda.
///
/// Anche su **localhost** (Flutter `web-server` / PWA in dev) la popup è spesso inaffidabile;
/// lo stesso vale per alcune **PWA desktop** se `display-mode: standalone` non viene rilevato.
bool garminWebPreferGarminSsoFullPage() {
  try {
    if (_navigatorStandaloneApplePwa()) return true;

    final host = html.window.location.hostname?.toLowerCase() ?? '';
    if (host == 'localhost' ||
        host == '127.0.0.1' ||
        host == '[::1]' ||
        host.endsWith('.localhost')) {
      return true;
    }

    final ua = html.window.navigator.userAgent.toLowerCase();
    if (ua.contains('iphone') || ua.contains('ipod') || ua.contains('ipad')) {
      return true;
    }

    final platform = html.window.navigator.platform?.toLowerCase() ?? '';
    final touch = html.window.navigator.maxTouchPoints ?? 0;
    if (platform.contains('mac') && touch > 1) {
      return true;
    }

    if (html.window.matchMedia('(display-mode: standalone)').matches) {
      return true;
    }
    if (html.window
        .matchMedia('(display-mode: window-controls-overlay)')
        .matches) {
      return true;
    }
  } on Object {
    return false;
  }
  return false;
}

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

/// URL assoluto di `web/garmin_oauth_prepare.html` (ponte prepare → Garmin, tap WebKit-safe).
Uri garminWebOAuthPreparePageUri() {
  final loc = Uri.parse(html.window.location.href);
  final base = loc.replace(query: '', fragment: '');
  final dir = base.resolve('.');
  var p = dir.path;
  if (!p.endsWith('/')) p = '$p/';
  return Uri(
    scheme: dir.scheme,
    host: dir.host,
    port: dir.hasPort ? dir.port : null,
    path: '${p}garmin_oauth_prepare.html',
  );
}

/// Navigazione **sincrona** (stesso turno del gesture) verso la pagina ponte; lì si fa `prepare` e poi il redirect a Garmin.
///
/// `uid` e `apiBase` viaggiano anche come query string così la pagina ponte funziona
/// anche se `sessionStorage` su iOS PWA o WebKit risulta vuoto al primo caricamento.
void garminWebNavigateToGarminOAuthPreparePage({
  String? uid,
  String? apiBase,
}) {
  final base = garminWebOAuthPreparePageUri();
  final params = <String, String>{};
  if (uid != null && uid.trim().isNotEmpty) {
    params['uid'] = uid.trim();
  }
  if (apiBase != null && apiBase.trim().isNotEmpty) {
    params['api_base'] = apiBase.trim();
  }
  final u = params.isEmpty
      ? base.toString()
      : base.replace(queryParameters: params).toString();
  _oauthWebLog('garminWebNavigateToGarminOAuthPreparePage: $u');
  html.window.location.assign(u);
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
