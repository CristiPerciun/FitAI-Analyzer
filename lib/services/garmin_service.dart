import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart'
    show debugPrint, kDebugMode, kIsWeb, visibleForTesting;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../models/fitness_data.dart';
import '../utils/platform_firestore_fix.dart';
import 'garmin_web_oauth_stub.dart'
    if (dart.library.html) 'garmin_web_oauth_web.dart'
    as garmin_web;

final garminServiceProvider = Provider<GarminService>((ref) => GarminService());

/// Trace multi‑riga (header, body snippet): solo se `.env` ha `GARMIN_HTTP_TRACE=1`
/// (anche in release/profile — utile sul dispositivo).
bool _garminHttpTraceFromEnv() {
  if (!dotenv.isInitialized) return false;
  final v = dotenv.env['GARMIN_HTTP_TRACE']?.trim().toLowerCase() ?? '';
  return v == '1' || v == 'true' || v == 'yes' || v == 'on';
}

/// Probe URL / richieste OK: solo in debug (console gestibile).
void _garminHttpVerbose(String message) {
  if (kDebugMode) {
    debugPrint('[GarminHTTP] $message');
  }
}

/// Errori HTTP / timeout / corpo risposta: sempre su console (anche profile) per diagnosticare Pi/DuckDNS.
void _garminHttpDiag(String message) {
  debugPrint('[GarminHTTP] $message');
}

/// Log OAuth Garmin su web: sempre in debug; in release/profile se `.env` ha
/// `GARMIN_OAUTH_WEB_DEBUG=1` (utile su iPhone / Chrome senza DevTools Dart).
bool _garminOAuthWebDebugEnabled() {
  if (kDebugMode) return true;
  if (!dotenv.isInitialized) return false;
  final v = dotenv.env['GARMIN_OAUTH_WEB_DEBUG']?.trim().toLowerCase() ?? '';
  return v == '1' || v == 'true' || v == 'yes' || v == 'on';
}

void _garminOAuthWebLog(String message) {
  if (_garminOAuthWebDebugEnabled()) {
    debugPrint('[GarminOAuthWeb] $message');
  }
}

String _ticketSnippetForLog(String? ticket) {
  if (ticket == null || ticket.isEmpty) return '(vuoto)';
  final t = ticket.trim();
  if (t.length <= 12) return '${t.substring(0, t.length)}… (len=${t.length})';
  return '${t.substring(0, 8)}…${t.substring(t.length - 4)} (len=${t.length})';
}

String _headersOneLine(Map<String, String> h) {
  final keys = h.keys.toList()..sort();
  return keys
      .map((k) {
        final v = h[k] ?? '';
        if (k.toLowerCase() == 'authorization') {
          return '$k: Bearer *** (len=${v.length})';
        }
        final short = v.length > 48 ? '${v.substring(0, 48)}…' : v;
        return '$k: $short';
      })
      .join('; ');
}

void _garminTraceHttpResponse({
  required String label,
  required Uri uri,
  required String method,
  required http.Response response,
  required int elapsedMs,
  Map<String, String>? requestHeaders,
  bool omitBody = false,
}) {
  if (!_garminHttpTraceFromEnv()) return;
  final ct = response.headers['content-type'] ?? 'n/a';
  final cl = response.headers['content-length'] ?? 'n/a';
  final body = omitBody
      ? '(omesso: endpoint sensibile)'
      : _responseBodySnippet(response.body, maxChars: 400);
  final reqH = requestHeaders != null
      ? _headersOneLine(requestHeaders)
      : '(n/a)';
  final respH = _headersOneLine(response.headers);
  debugPrint(
    '[GarminHTTP] trace $label $method $uri → ${response.statusCode} '
    '${elapsedMs}ms\n'
    '  req_headers: $reqH\n'
    '  resp: content-type=$ct content-length=$cl\n'
    '  resp_headers: $respH\n'
    '  body: $body',
  );
}

String _responseBodySnippet(String body, {int maxChars = 480}) {
  final t = body.trim();
  if (t.isEmpty) return '(corpo vuoto)';
  final oneLine = t.replaceAll(RegExp(r'\s+'), ' ');
  if (oneLine.length <= maxChars) return oneLine;
  return '${oneLine.substring(0, maxChars)}…';
}

String? _extractGarminLoginUrl(String raw) {
  final match = RegExp(
    r'https://sso\.garmin\.com/sso/signin\?[^\s"}]+',
  ).firstMatch(raw);
  return match?.group(0);
}

/// Messaggio utente + contesto quando il server non risponde 200 con JSON utile.
String _connectFailureUserMessage({
  required int statusCode,
  required String baseUrl,
  required String body,
  required String? serverDetail,
}) {
  if (serverDetail != null && serverDetail.isNotEmpty) {
    return serverDetail;
  }
  final snippet = _responseBodySnippet(body);
  if (statusCode == 502 || statusCode == 503 || statusCode == 504) {
    final looksLikeNginxHtml =
        body.trim().startsWith('<') ||
        snippet.toLowerCase().contains('bad gateway');
    final nginxHint = looksLikeNginxHtml
        ? ' Spesso è nginx/DuckDNS che non raggiunge uvicorn sul Pi (servizio spento o proxy).'
        : ' Verifica che garmin-sync sul Pi sia attivo e raggiungibile dietro il proxy.';
    return 'Server HTTP $statusCode ($baseUrl).$nginxHint Dettaglio: $snippet';
  }
  return 'Risposta server HTTP $statusCode da $baseUrl. $snippet';
}

/// Normalizza base URL (spazi, slash finali). Utile se nginx è su :80 senza path.
@visibleForTesting
String normalizeGarminServerBaseUrl(String raw) {
  var s = raw.trim();
  while (s.endsWith('/')) {
    s = s.substring(0, s.length - 1);
  }
  return s;
}

/// URL LAN: stesso Wi‑Fi del Pi (spesso nginx :80, es. `http://192.168.1.200`).
String get _garminServerUrlLan {
  const def = 'http://192.168.1.200';
  if (!dotenv.isInitialized) return normalizeGarminServerBaseUrl(def);
  final u = dotenv.env['GARMIN_SERVER_URL_LAN']?.trim();
  return normalizeGarminServerBaseUrl((u != null && u.isNotEmpty) ? u : def);
}

/// URL remoto: quando sei fuori casa (DuckDNS + HTTPS).
String get _garminServerUrlRemote {
  const def = 'https://myrasberrysyncgar.duckdns.org';
  if (!dotenv.isInitialized) return normalizeGarminServerBaseUrl(def);
  final u = dotenv.env['GARMIN_SERVER_URL_REMOTE']?.trim();
  return normalizeGarminServerBaseUrl((u != null && u.isNotEmpty) ? u : def);
}

/// URL legacy (compatibilita): se impostato, usa solo quello.
String get garminServerUrl {
  if (!dotenv.isInitialized) return _garminServerUrlLan;
  final u = dotenv.env['GARMIN_SERVER_URL']?.trim();
  if (u != null && u.isNotEmpty) return normalizeGarminServerBaseUrl(u);
  return _garminServerUrlLan;
}

/// Servizio per lettura dati Garmin da Firestore e connessione via server.
/// I dati sono scritti dal garmin-sync-server Python (es. su Raspberry Pi).
/// Collezioni: users/{uid}/activities, users/{uid}/daily_health
class GarminService {
  GarminService({http.Client? httpClient, String? serverUrlOverride})
    : _http = httpClient ?? http.Client(),
      _serverUrlOverride = serverUrlOverride;

  final http.Client _http;
  final String? _serverUrlOverride;

  /// URL risolto: LAN (a casa) o REMOTE (fuori). Cache per evitare probe ripetuti.
  String? _cachedBaseUrl;

  /// Timeout per probe LAN iniziale (fuori casa = attesa fino a timeout poi REMOTE).
  static const Duration _lanProbeTimeout = Duration(seconds: 3);

  /// Se la cache punta alla LAN, rivalidiamo così uscendo di casa non restiamo bloccati sull'IP interno.
  static const Duration _lanRevalidateTimeout = Duration(seconds: 2);

  /// Lazy: evita `Firebase.initializeApp()` quando si usano solo connect/sync/disconnect (es. test).
  FirebaseFirestore get _firestore => FirebaseFirestore.instance;

  void _invalidateBaseUrlCacheOnNetworkFailure(Object error) {
    final s = error.toString().toLowerCase();
    final likelyNetwork =
        error is TimeoutException ||
        s.contains('socket') ||
        s.contains('connection') ||
        s.contains('failed host lookup') ||
        s.contains('network') ||
        s.contains('host lookup');
    if (!likelyNetwork) return;
    _cachedBaseUrl = null;
    _garminHttpDiag('cache base URL azzerata dopo errore rete: $error');
  }

  /// Risolve URL: prova LAN prima (192.168.1.200:8080), se fallisce usa REMOTE (DuckDNS).
  /// A casa: LAN raggiungibile. Fuori: solo REMOTE.
  /// Se GARMIN_SERVER_URL e' impostato, usa solo quello (override).
  Future<String> _resolveBaseUrl() async {
    final o = _serverUrlOverride?.trim();
    if (o != null && o.isNotEmpty) {
      _garminHttpVerbose('URL server = override costruttore: $o');
      return o;
    }

    if (dotenv.isInitialized) {
      final forced = dotenv.env['GARMIN_SERVER_URL']?.trim();
      if (forced != null && forced.isNotEmpty) {
        _garminHttpVerbose(
          'URL server = GARMIN_SERVER_URL (auto-detect LAN/REMOTE disattivato): $forced',
        );
        return forced;
      }
    }

    final lan = _garminServerUrlLan;
    final remote = _garminServerUrlRemote;

    // Web: non fare probe LAN (spesso 3s di timeout fuori casa / mixed-content HTTPS→HTTP).
    // `exchange-ticket` deve partire subito: i service ticket Garmin scadono in pochi secondi.
    if (kIsWeb) {
      if (_cachedBaseUrl != null) {
        final c = _cachedBaseUrl!;
        if (c == lan) {
          _garminHttpDiag(
            'Web: cache LAN ignorata -> REMOTE ($remote) (OAuth/ticket time-sensitive)',
          );
          _cachedBaseUrl = remote;
          return remote;
        }
        _garminHttpVerbose('Web: cache base URL -> $c');
        return c;
      }
      _cachedBaseUrl = remote;
      _garminHttpVerbose(
        'Web: REMOTE senza probe LAN -> $remote '
        '(per forzare un URL diverso usa GARMIN_SERVER_URL in .env)',
      );
      return remote;
    }

    if (_cachedBaseUrl != null) {
      final cached = _cachedBaseUrl!;
      if (cached == lan) {
        _garminHttpVerbose(
          'Cache LAN ($lan): check rapido ${_lanRevalidateTimeout.inSeconds}s...',
        );
        try {
          final sw = Stopwatch()..start();
          final r = await _http
              .get(Uri.parse('$lan/'))
              .timeout(_lanRevalidateTimeout);
          _garminTraceHttpResponse(
            label: 'resolveBaseUrl LAN revalidate',
            uri: Uri.parse('$lan/'),
            method: 'GET',
            response: r,
            elapsedMs: sw.elapsedMilliseconds,
          );
          if (r.statusCode == 200) {
            _garminHttpVerbose(
              'LAN ancora OK (${sw.elapsedMilliseconds}ms) -> $lan',
            );
            return lan;
          }
          _garminHttpVerbose(
            'LAN risponde HTTP ${r.statusCode}, ricalcolo base URL',
          );
        } on Object catch (e) {
          _garminHttpVerbose(
            'LAN non raggiungibile (check rapido): $e -> probe completo / REMOTE',
          );
        }
        _cachedBaseUrl = null;
      } else {
        _garminHttpVerbose('Cache REMOTE -> $cached');
        return cached;
      }
    }

    _garminHttpVerbose(
      'Probe LAN ${_lanProbeTimeout.inSeconds}s: $lan (se timeout -> $remote)',
    );
    try {
      final sw = Stopwatch()..start();
      final r = await _http.get(Uri.parse('$lan/')).timeout(_lanProbeTimeout);
      _garminTraceHttpResponse(
        label: 'resolveBaseUrl LAN probe',
        uri: Uri.parse('$lan/'),
        method: 'GET',
        response: r,
        elapsedMs: sw.elapsedMilliseconds,
      );
      if (r.statusCode == 200) {
        _cachedBaseUrl = lan;
        _garminHttpVerbose('LAN OK (${sw.elapsedMilliseconds}ms) -> base $lan');
        return lan;
      }
      _garminHttpVerbose('LAN HTTP ${r.statusCode} -> uso REMOTE');
    } on Object catch (e) {
      _garminHttpVerbose('LAN non disponibile: $e -> uso REMOTE');
    }
    _cachedBaseUrl = remote;
    _garminHttpVerbose('Base URL finale -> $remote');
    return remote;
  }

  Map<String, String> get _jsonHeaders {
    final h = <String, String>{'Content-Type': 'application/json'};
    if (dotenv.isInitialized) {
      final token = dotenv.env['GARMIN_SERVER_BEARER_TOKEN']?.trim();
      if (token != null && token.isNotEmpty) {
        h['Authorization'] = 'Bearer $token';
      }
    }
    return h;
  }

  /// Stream real-time attività unificate (Garmin, Strava o dual) ordinate per startTime.
  /// Su Windows usa polling per evitare errori "non-platform thread".
  Stream<List<FitnessData>> activitiesStream(String uid) {
    final query = _firestore
        .collection('users')
        .doc(uid)
        .collection('activities')
        .orderBy('startTime', descending: true)
        .limit(60);
    return querySnapshotStream(query).map(
      (snap) => snap.docs
          .map((d) => FitnessData.fromJson({...d.data(), 'id': d.id}))
          .toList(),
    );
  }

  /// Timeout per connect: 90s (OAuth Garmin + rete lenta / Pi che si sveglia).
  static const Duration _connectTimeout = Duration(seconds: 90);

  /// Pull-to-refresh: solo oggi/ieri + attività recenti (server `sync-today`).
  static const Duration _syncTodayTimeout = Duration(seconds: 60);

  /// Delta all'avvio (Garmin + Strava lato server).
  static const Duration _deltaTimeout = Duration(seconds: 120);
  static bool _garminWebOAuthInFlight = false;
  static String? _garminWebLastExchangedTicket;
  static const String _garminWebSessionResultKey = 'garmin_oauth_result';
  static const String _garminWebSessionMessageKey = 'garmin_oauth_message';

  Map<String, dynamic>? consumeGarminWebOAuthSessionResult() {
    if (!kIsWeb) return null;
    final status = garmin_web.garminWebSessionGet(_garminWebSessionResultKey);
    final message = garmin_web.garminWebSessionGet(_garminWebSessionMessageKey);
    if ((status == null || status.isEmpty) &&
        (message == null || message.isEmpty)) {
      return null;
    }
    _garminOAuthWebLog(
      'consumeGarminWebOAuthSessionResult: status=$status message=${message ?? ''}',
    );
    garmin_web.garminWebSessionRemove(_garminWebSessionResultKey);
    garmin_web.garminWebSessionRemove(_garminWebSessionMessageKey);
    return {
      'success': status == 'success',
      'message': message ?? '',
    };
  }

  /// URL di ritorno base per Garmin OAuth su web (stesso host/path, senza query/fragment).
  static Uri garminWebRedirectBase(Uri loc) {
    var path = loc.path;
    if (path.isEmpty) {
      path = '/';
    }
    return Uri(
      scheme: loc.scheme,
      host: loc.host.toLowerCase(),
      port: loc.hasPort ? loc.port : null,
      path: path,
    );
  }

  @visibleForTesting
  static String? extractGarminTicketFromUri(Uri loc) {
    var t = loc.queryParameters['ticket'];
    if (t != null && t.isNotEmpty) return t;
    final frag = loc.fragment;
    if (frag.isEmpty) return null;
    final q = frag.startsWith('?') ? frag.substring(1) : frag;
    try {
      t = Uri.splitQueryString(q)['ticket'];
      if (t != null && t.isNotEmpty) return t;
    } on Object {
      return null;
    }
    return null;
  }

  static String? _garminOAuthErrorFromUri(Uri loc) {
    var e = loc.queryParameters['error'];
    if (e != null && e.isNotEmpty) return e;
    final frag = loc.fragment;
    if (frag.isEmpty) return null;
    final q = frag.startsWith('?') ? frag.substring(1) : frag;
    try {
      e = Uri.splitQueryString(q)['error'];
    } on Object {
      return null;
    }
    return (e != null && e.isNotEmpty) ? e : null;
  }

  /// Formato atteso da `POST /garmin/connect3/exchange-ticket` (come redirect mobile/embed).
  @visibleForTesting
  static String garminTicketToEmbedUrl(String ticket) {
    return 'https://sso.garmin.com/sso/embed?ticket=${Uri.encodeQueryComponent(ticket)}';
  }

  /// URL signin Garmin per piattaforme **native** (FlutterWebAuth2).
  ///
  /// Usa `embedWidget=true` + `gauthHost=sso.garmin.com/sso/embed` in modo che
  /// FlutterWebAuth2 intercetti il redirect verso `https://sso.garmin.com/sso/embed?ticket=…`.
  static String buildGarminWebSsoSigninUrl(String serviceUrl) {
    const garminEmbedHost = 'https://sso.garmin.com/sso/embed';
    final base = Uri.parse('https://sso.garmin.com/sso/signin');
    return base
        .replace(
          queryParameters: {
            'id': 'gauth-widget',
            'embedWidget': 'true',
            'gauthHost': garminEmbedHost,
            'service': serviceUrl,
            'source': serviceUrl,
            'redirectAfterAccountLoginUrl': serviceUrl,
            'redirectAfterAccountCreationUrl': serviceUrl,
          },
        )
        .toString();
  }

  /// URL signin Garmin per il **popup web** (flusso CAS puro, senza embedWidget).
  ///
  /// `embedWidget=true` + `gauthHost` fanno sì che Garmin rediriga verso il gauthHost
  /// ignorando il `service` personalizzato — il popup non raggiungerebbe mai
  /// `garmin_oauth_return.html`. Usando il flusso CAS standard il redirect va
  /// direttamente al `service` → `garmin_oauth_return.html?ticket=ST-…`.
  static String buildGarminPopupSsoLoginUrl(String returnPageUrl) {
    // Non usiamo id=gauth-widget né embedWidget: la modalità widget di Garmin
    // usa navigazione JS (non HTTP 302) e su iOS/Safari può non reindirizzare
    // correttamente al service URL. Il flusso CAS standard garantisce un redirect
    // HTTP 302 affidabile su tutti i browser.
    return Uri.parse('https://sso.garmin.com/sso/signin')
        .replace(
          queryParameters: {
            'service': returnPageUrl,
            'source': returnPageUrl,
            'redirectAfterAccountLoginUrl': returnPageUrl,
            'redirectAfterAccountCreationUrl': returnPageUrl,
          },
        )
        .toString();
  }

  /// SSO Garmin su web.
  ///
  /// Apre `garmin_oauth_return.html` come `service` redirect di Garmin SSO (flusso CAS puro).
  /// Dopo il login, Garmin redirige a `garmin_oauth_return.html?ticket=ST-…`.
  /// Su desktop il ticket torna al parent via `postMessage`; su iOS la return page
  /// esegue lo scambio col server e poi rientra nell'app.
  Future<Map<String, dynamic>> connectViaGarminSsoWeb({
    required String uid,
  }) async {
    if (!kIsWeb) {
      return {'success': false, 'message': 'Metodo solo per web.'};
    }
    final baseUrl = await _resolveBaseUrl();
    final isIos = garmin_web.garminWebIsIos();
    final authHeader = _jsonHeaders['Authorization']?.trim() ?? '';
    final currentHref = garmin_web.garminWebCurrentUri()?.toString() ?? '(n/a)';
    _garminOAuthWebLog(
      'connectViaGarminSsoWeb: uid=$uid isIos=$isIos baseUrl=$baseUrl '
      'bearer=${authHeader.isNotEmpty}',
    );
    _garminOAuthWebLog('connectViaGarminSsoWeb: window.href=$currentHref');

    final loc = garmin_web.garminWebCurrentUri();
    if (loc == null) {
      return {
        'success': false,
        'message': 'URL corrente non disponibile (Garmin web).',
      };
    }

    // ── iOS Safari / PWA (iPhone/iPad): apriamo una finestra script-opened.
    //    Prima apriamo una pagina locale che salva il contesto nel popup stesso,
    //    poi navighiamo a Garmin. La return page fa l'exchange del ticket e poi prova a chiudersi con
    //    `window.close()`, riportando l'utente alla PWA.
    if (isIos) {
      final returnPage = garmin_web.garminWebOAuthReturnPageUri().toString();
      final ssoUrl = buildGarminPopupSsoLoginUrl(returnPage);
      _garminOAuthWebLog('connectViaGarminSsoWeb: iOS returnPage(service)=$returnPage');
      _garminOAuthWebLog('connectViaGarminSsoWeb: iOS ssoUrl=$ssoUrl');
      final startPage = garmin_web
          .garminWebOAuthStartPageUri()
          .replace(
            fragment: Uri(
              queryParameters: {
                'uid': uid,
                'base_url': baseUrl,
                'sso_url': ssoUrl,
                if (authHeader.isNotEmpty) 'auth': authHeader,
                'ios_popup': '1',
              },
            ).query,
          )
          .toString();
      _garminHttpVerbose('Web SSO iOS popup/open start-page → $startPage');
      _garminOAuthWebLog('iOS: startPage=$startPage');
      final opened = garmin_web.garminWebOpenPopup(startPage);
      if (!opened) {
        _garminOAuthWebLog('iOS: window.open(startPage) ha restituito null (popup bloccato?)');
        return {
          'success': false,
          'message': 'Il browser ha bloccato l\'apertura della pagina Garmin.',
        };
      }
      _garminOAuthWebLog('iOS: popup aperta, in attesa return page + exchange');
      return {'success': null, 'ios_redirect': true};
    }

    // Desktop / Android browser: navigazione full-page verso Garmin (flusso legacy
    // ~04896ea). Il `service` è l'URL base dell'app; dopo il login Garmin torna con
    // `?ticket=` sulla stessa scheda e `completeGarminWebOAuthIfPresent` completa.
    final callbackUrl = garminWebRedirectBase(loc).toString();
    final ssoUrl = buildGarminPopupSsoLoginUrl(callbackUrl);
    _garminHttpVerbose('Web SSO full-page: navigazione → $ssoUrl');
    _garminOAuthWebLog(
      'desktop/Android: full-page callback(service)=$callbackUrl',
    );
    _garminOAuthWebLog('desktop/Android: ssoUrl=$ssoUrl');
    garmin_web.garminWebAssignLocation(ssoUrl);
    return {'success': null, 'web_redirect': true};
  }

  /// Completa OAuth Garmin su web quando l'app ha `?ticket=...` (o errore) dopo il redirect.
  Future<Map<String, dynamic>?> completeGarminWebOAuthIfPresent({
    required String uid,
  }) async {
    if (!kIsWeb) return null;
    final loc = garmin_web.garminWebCurrentUri();
    if (loc == null) return null;

    final ticket = extractGarminTicketFromUri(loc);
    final error = _garminOAuthErrorFromUri(loc);
    if ((ticket == null || ticket.isEmpty) &&
        (error == null || error.isEmpty)) {
      return null;
    }

    _garminOAuthWebLog(
      'completeGarminWebOAuthIfPresent: href=${loc.toString()} '
      'ticket=${_ticketSnippetForLog(ticket)} error=${error ?? ''}',
    );

    if (_garminWebOAuthInFlight) return null;
    if (ticket != null &&
        ticket.isNotEmpty &&
        _garminWebLastExchangedTicket == ticket) {
      _garminOAuthWebLog('completeGarminWebOAuthIfPresent: ticket già scambiato, skip');
      final clean = garminWebRedirectBase(loc);
      garmin_web.garminWebReplaceCleanUrl(clean);
      return null;
    }

    _garminWebOAuthInFlight = true;
    final clean = garminWebRedirectBase(loc);
    garmin_web.garminWebReplaceCleanUrl(clean);

    try {
      if (error != null && error.isNotEmpty) {
        _garminOAuthWebLog('completeGarminWebOAuthIfPresent: errore OAuth in URL');
        return {'success': false, 'message': 'Garmin: $error'};
      }
      // Costruiamo ticketOrUrl come returnPage?ticket=ST-...
      // In questo modo il server può estrarre il login-url corretto (= returnPage)
      // da passare a connectapi.garmin.com/oauth-service/oauth/preauthorized.
      final String ticketOrUrl;
      if (ticket != null && ticket.isNotEmpty) {
        // `login-url` sul server deve coincidere col `service` usato col ticket
        // (app principale `/` oppure `garmin_oauth_return.html` su iOS popup).
        ticketOrUrl = garminWebRedirectBase(loc)
            .replace(queryParameters: {'ticket': ticket})
            .toString();
      } else {
        ticketOrUrl = loc.toString();
      }
      _garminOAuthWebLog(
        'completeGarminWebOAuthIfPresent: exchange-ticket (URL app) ticketOrUrl len=${ticketOrUrl.length}',
      );
      final result = await connect3ExchangeTicket(
        uid: uid,
        ticketOrUrl: ticketOrUrl,
      );
      _garminOAuthWebLog(
        'completeGarminWebOAuthIfPresent: exchange risultato success=${result['success']} message=${result['message']}',
      );
      if (result['success'] == true && ticket != null && ticket.isNotEmpty) {
        _garminWebLastExchangedTicket = ticket;
      }
      return result;
    } finally {
      _garminWebOAuthInFlight = false;
    }
  }

  Future<bool> isConnected(String uid) async {
    final doc = await _firestore.collection('users').doc(uid).get();
    return doc.data()?['garmin_linked'] == true;
  }

  /// Ultimo sync completo lato server (per `POST /sync/delta`).
  Future<Timestamp?> getLastSuccessfulSync(String uid) async {
    final doc = await _firestore.collection('users').doc(uid).get();
    final v = doc.data()?['lastSuccessfulSync'];
    return v is Timestamp ? v : null;
  }

  static Map<String, dynamic>? _tryDecodeJsonObject(String body) {
    final t = body.trim();
    if (t.isEmpty) return null;
    try {
      final v = jsonDecode(t);
      return v is Map<String, dynamic> ? v : null;
    } on Object {
      return null;
    }
  }

  static String _serverDetailOrMessage(Map<String, dynamic>? data) {
    if (data == null) return '';
    final d = data['detail'];
    if (d is String && d.isNotEmpty) return d;
    if (d is List && d.isNotEmpty) return d.map((e) => e.toString()).join('; ');
    final m = data['message'];
    if (m is String && m.isNotEmpty) return m;
    return '';
  }

  Future<Map<String, dynamic>> connect2Start({
    required String uid,
    required String email,
    required String password,
  }) async {
    return _connect2Post(
      path: '/garmin/connect2/start',
      body: {'uid': uid, 'email': email.trim(), 'password': password},
      logLabel: 'garmin/connect2/start',
    );
  }

  Future<Map<String, dynamic>> connect2VerifyMfa({
    required String uid,
    required String loginSessionId,
    required String mfaCode,
  }) async {
    return _connect2Post(
      path: '/garmin/connect2/verify-mfa',
      body: {
        'uid': uid,
        'login_session_id': loginSessionId,
        'mfa_code': mfaCode.trim(),
      },
      logLabel: 'garmin/connect2/verify-mfa',
    );
  }

  Future<Map<String, dynamic>> connect3ExchangeTicket({
    required String uid,
    required String ticketOrUrl,
    String? email,
  }) async {
    return _connect2Post(
      path: '/garmin/connect3/exchange-ticket',
      body: {
        'uid': uid,
        'ticket_or_url': ticketOrUrl,
        if (email != null && email.trim().isNotEmpty) 'email': email.trim(),
      },
      logLabel: 'garmin/connect3/exchange-ticket',
    );
  }

  Future<Map<String, dynamic>> _connect2Post({
    required String path,
    required Map<String, dynamic> body,
    required String logLabel,
  }) async {
    final baseUrl = await _resolveBaseUrl();
    final uri = Uri.parse('$baseUrl$path');
    try {
      _garminHttpVerbose(
        'POST $uri ($logLabel, timeout ${_connectTimeout.inSeconds}s)',
      );
      final sw = Stopwatch()..start();
      final response = await _http
          .post(uri, headers: _jsonHeaders, body: jsonEncode(body))
          .timeout(_connectTimeout);
      _garminTraceHttpResponse(
        label: logLabel,
        uri: uri,
        method: 'POST',
        response: response,
        elapsedMs: sw.elapsedMilliseconds,
        requestHeaders: _jsonHeaders,
      );
      final status = response.statusCode;
      if (status != 200) {
        _garminHttpDiag(
          'POST $path <- $status in ${sw.elapsedMilliseconds}ms '
          'baseUrl=$baseUrl body=${_responseBodySnippet(response.body)}',
        );
      }
      final data = _tryDecodeJsonObject(response.body);
      if (data != null) {
        final message = _serverDetailOrMessage(data);
        final loginUrl =
            (data['loginUrl'] is String &&
                (data['loginUrl'] as String).isNotEmpty)
            ? data['loginUrl'] as String
            : _extractGarminLoginUrl(message);
        return {
          'success': data['success'] == true,
          'message': message,
          if (data['mfaRequired'] == true) 'mfaRequired': true,
          if (data['loginSessionId'] is String)
            'loginSessionId': data['loginSessionId'],
          'loginUrl': ?loginUrl,
        };
      }
      return {
        'success': false,
        'message': _connectFailureUserMessage(
          statusCode: status,
          baseUrl: baseUrl,
          body: response.body,
          serverDetail: null,
        ),
      };
    } on TimeoutException catch (e) {
      _invalidateBaseUrlCacheOnNetworkFailure(e);
      _garminHttpDiag('$logLabel TIMEOUT verso $baseUrl ($e)');
      return {
        'success': false,
        'message': 'Timeout durante Garmin Connect 2 verso $baseUrl.',
      };
    } on Object catch (e) {
      _invalidateBaseUrlCacheOnNetworkFailure(e);
      _garminHttpDiag('$logLabel errore: $e (baseUrl=$baseUrl)');
      return {'success': false, 'message': 'Errore di rete: $e'};
    }
  }

  /// Scollega l'account Garmin: elimina token sul server e aggiorna Firestore.
  Future<Map<String, dynamic>> disconnect({required String uid}) async {
    final baseUrl = await _resolveBaseUrl();
    final uri = Uri.parse('$baseUrl/garmin/disconnect');
    try {
      _garminHttpVerbose('POST $uri (disconnect)');
      final sw = Stopwatch()..start();
      final response = await _http
          .post(uri, headers: _jsonHeaders, body: jsonEncode({'uid': uid}))
          .timeout(const Duration(seconds: 30));
      _garminTraceHttpResponse(
        label: 'garmin/disconnect',
        uri: uri,
        method: 'POST',
        response: response,
        elapsedMs: sw.elapsedMilliseconds,
        requestHeaders: _jsonHeaders,
      );
      final dStatus = response.statusCode;
      if (dStatus == 200) {
        _garminHttpVerbose(
          'POST /garmin/disconnect <- $dStatus in ${sw.elapsedMilliseconds}ms',
        );
      } else {
        _garminHttpDiag(
          'POST /garmin/disconnect <- $dStatus baseUrl=$baseUrl '
          'body=${_responseBodySnippet(response.body)}',
        );
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode == 200 && data['success'] == true) {
        return {
          'success': true,
          'message': data['message']?.toString() ?? 'Garmin scollegato.',
        };
      }
      return {
        'success': false,
        'message': data['detail']?.toString() ?? 'Disconnessione non riuscita.',
      };
    } on TimeoutException catch (e) {
      _invalidateBaseUrlCacheOnNetworkFailure(e);
      _garminHttpDiag('disconnect TIMEOUT verso $baseUrl');
      return {'success': false, 'message': 'Server non risponde. Riprova.'};
    } on Exception catch (e) {
      _invalidateBaseUrlCacheOnNetworkFailure(e);
      final msg = e.toString().toLowerCase();
      _garminHttpDiag('disconnect errore: $e (baseUrl=$baseUrl)');
      return {
        'success': false,
        'message': msg.contains('socket') || msg.contains('connection')
            ? 'Server non raggiungibile.'
            : 'Errore di rete.',
      };
    }
  }

  /// Sync leggera: `POST /garmin/sync-today` (oggi/ieri + attività recenti).
  Future<Map<String, dynamic>> syncToday({required String uid}) async {
    return _postUidWithRetries(
      path: '/garmin/sync-today',
      uid: uid,
      timeout: _syncTodayTimeout,
      logLabel: 'sync-today',
    );
  }

  /// Delta unificato dopo login: `POST /sync/delta`.
  Future<Map<String, dynamic>> deltaSync({
    required String uid,
    Timestamp? lastSuccessfulSync,
    List<String> sources = const ['garmin', 'strava'],
  }) async {
    final body = <String, dynamic>{'uid': uid, 'sources': sources};
    if (lastSuccessfulSync != null) {
      body['lastSuccessfulSync'] = lastSuccessfulSync
          .toDate()
          .toUtc()
          .millisecondsSinceEpoch;
    }

    Future<Map<String, dynamic>> doRequest() async {
      final baseUrl = await _resolveBaseUrl();
      final uri = Uri.parse('$baseUrl/sync/delta');
      _garminHttpVerbose(
        'POST $uri (delta, timeout ${_deltaTimeout.inSeconds}s)',
      );
      final sw = Stopwatch()..start();
      final response = await _http
          .post(uri, headers: _jsonHeaders, body: jsonEncode(body))
          .timeout(_deltaTimeout);
      _garminTraceHttpResponse(
        label: 'sync/delta',
        uri: uri,
        method: 'POST',
        response: response,
        elapsedMs: sw.elapsedMilliseconds,
        requestHeaders: _jsonHeaders,
      );
      final st = response.statusCode;
      if (st == 200) {
        _garminHttpVerbose(
          'POST /sync/delta <- $st in ${sw.elapsedMilliseconds}ms',
        );
      } else {
        _garminHttpDiag(
          'POST /sync/delta <- $st in ${sw.elapsedMilliseconds}ms baseUrl=$baseUrl '
          'body=${_responseBodySnippet(response.body)}',
        );
      }

      if (st >= 500 && st < 600) {
        throw Exception('Server unavailable');
      }

      final raw = response.body.trim();
      Map<String, dynamic> data;
      try {
        data = raw.isEmpty
            ? <String, dynamic>{}
            : jsonDecode(raw) as Map<String, dynamic>;
      } on Object catch (e) {
        _garminHttpDiag('delta: JSON decode fallito: $e');
        return {
          'success': false,
          'message': _connectFailureUserMessage(
            statusCode: st,
            baseUrl: baseUrl,
            body: response.body,
            serverDetail: null,
          ),
        };
      }

      if (st == 200 && data['success'] == true) {
        return {
          'success': true,
          'message': data['message']?.toString() ?? 'Delta sync completata.',
        };
      }

      final detail = _serverDetailOrMessage(data);
      if (detail.isNotEmpty) {
        return {'success': false, 'message': detail};
      }
      return {
        'success': false,
        'message':
            data['message']?.toString() ??
            _connectFailureUserMessage(
              statusCode: st,
              baseUrl: baseUrl,
              body: response.body,
              serverDetail: null,
            ),
      };
    }

    try {
      return await doRequest();
    } on TimeoutException catch (e) {
      _invalidateBaseUrlCacheOnNetworkFailure(e);
      await Future<void>.delayed(const Duration(seconds: 3));
      try {
        return await doRequest();
      } on Object catch (e2) {
        _invalidateBaseUrlCacheOnNetworkFailure(e2);
        return {
          'success': false,
          'message': 'Delta sync: timeout o errore di rete.',
        };
      }
    } on Exception catch (e) {
      _invalidateBaseUrlCacheOnNetworkFailure(e);
      final msg = e.toString().toLowerCase();
      if (msg.contains('socket') ||
          msg.contains('connection') ||
          msg.contains('unavailable')) {
        await Future<void>.delayed(const Duration(seconds: 3));
        try {
          return await doRequest();
        } on Object catch (e2) {
          _invalidateBaseUrlCacheOnNetworkFailure(e2);
        }
      }
      return {
        'success': false,
        'message': 'Errore di rete durante la delta sync.',
      };
    }
  }

  /// Scambia `code` OAuth con token (solo **web**): il browser non può POSTare a
  /// `https://www.strava.com/oauth/token` per CORS.
  ///
  /// Serve su **garmin-sync-server** un endpoint `POST /strava/exchange-oauth-code`
  /// con body JSON `{ "uid", "code", "redirect_uri" }` che esegue il POST server-side
  /// verso Strava (`client_id`, `client_secret`, `code`, `grant_type=authorization_code`,
  /// `redirect_uri`) e risponde con gli stessi campi token di Strava + `success: true`.
  Future<Map<String, dynamic>> exchangeStravaOAuthCodeOnServer({
    required String uid,
    required String code,
    required String redirectUri,
  }) async {
    final baseUrl = await _resolveBaseUrl();
    final uri = Uri.parse('$baseUrl/strava/exchange-oauth-code');
    final body = <String, dynamic>{
      'uid': uid,
      'code': code,
      'redirect_uri': redirectUri,
    };
    try {
      final sw = Stopwatch()..start();
      final response = await _http
          .post(uri, headers: _jsonHeaders, body: jsonEncode(body))
          .timeout(const Duration(seconds: 45));
      _garminTraceHttpResponse(
        label: 'strava/exchange-oauth-code',
        uri: uri,
        method: 'POST',
        response: response,
        elapsedMs: sw.elapsedMilliseconds,
        requestHeaders: _jsonHeaders,
        omitBody: true,
      );
      final data = _tryDecodeJsonObject(response.body);
      if (response.statusCode == 200 &&
          data != null &&
          data['success'] == true) {
        return {
          'success': true,
          'access_token': data['access_token'],
          'refresh_token': data['refresh_token'],
          'expires_in': data['expires_in'],
          'expires_at': data['expires_at'],
        };
      }
      if (response.statusCode == 404) {
        return {
          'success': false,
          'message':
              'Server Garmin non espone ancora POST /strava/exchange-oauth-code '
              '(necessario per Strava su web). Aggiorna garmin-sync-server.',
        };
      }
      return {
        'success': false,
        'message': _serverDetailOrMessage(data).isNotEmpty
            ? _serverDetailOrMessage(data)
            : 'Exchange OAuth Strava sul server non riuscito (HTTP ${response.statusCode}).',
      };
    } on Object catch (e) {
      _invalidateBaseUrlCacheOnNetworkFailure(e);
      return {'success': false, 'message': 'Errore di rete: $e'};
    }
  }

  /// Registra token Strava sul server (backfill 60gg in background).
  Future<Map<String, dynamic>> registerStravaOnServer({
    required String uid,
    required String accessToken,
    required String refreshToken,
    int? expiresAtMs,
  }) async {
    final baseUrl = await _resolveBaseUrl();
    final uri = Uri.parse('$baseUrl/strava/register-tokens');
    final body = <String, dynamic>{
      'uid': uid,
      'access_token': accessToken,
      'refresh_token': refreshToken,
    };
    if (expiresAtMs != null) {
      body['expires_at'] = expiresAtMs;
    }
    try {
      final swReg = Stopwatch()..start();
      final response = await _http
          .post(uri, headers: _jsonHeaders, body: jsonEncode(body))
          .timeout(const Duration(seconds: 45));
      _garminTraceHttpResponse(
        label: 'strava/register-tokens',
        uri: uri,
        method: 'POST',
        response: response,
        elapsedMs: swReg.elapsedMilliseconds,
        requestHeaders: _jsonHeaders,
        omitBody: true,
      );
      final data = _tryDecodeJsonObject(response.body);
      if (response.statusCode == 200 &&
          data != null &&
          data['success'] == true) {
        return {
          'success': true,
          'message':
              data['message']?.toString() ?? 'Strava registrato sul server.',
        };
      }
      return {
        'success': false,
        'message': _serverDetailOrMessage(data).isNotEmpty
            ? _serverDetailOrMessage(data)
            : 'Registrazione Strava sul server non riuscita.',
      };
    } on Object catch (e) {
      _invalidateBaseUrlCacheOnNetworkFailure(e);
      return {'success': false, 'message': 'Errore di rete: $e'};
    }
  }

  /// Rimuove token Strava lato server (solo Firestore server-side).
  Future<Map<String, dynamic>> disconnectStravaOnServer({
    required String uid,
  }) async {
    final baseUrl = await _resolveBaseUrl();
    final uri = Uri.parse('$baseUrl/strava/disconnect');
    try {
      final swSd = Stopwatch()..start();
      final response = await _http
          .post(uri, headers: _jsonHeaders, body: jsonEncode({'uid': uid}))
          .timeout(const Duration(seconds: 30));
      _garminTraceHttpResponse(
        label: 'strava/disconnect',
        uri: uri,
        method: 'POST',
        response: response,
        elapsedMs: swSd.elapsedMilliseconds,
        requestHeaders: _jsonHeaders,
        omitBody: true,
      );
      final data = _tryDecodeJsonObject(response.body);
      if (response.statusCode == 200 &&
          data != null &&
          data['success'] == true) {
        return {'success': true};
      }
      return {'success': false};
    } on Object catch (_) {
      return {'success': false};
    }
  }

  Future<Map<String, dynamic>> _postUidWithRetries({
    required String path,
    required String uid,
    required Duration timeout,
    required String logLabel,
  }) async {
    Future<Map<String, dynamic>> doRequest() async {
      final baseUrl = await _resolveBaseUrl();
      final syncUri = Uri.parse('$baseUrl$path');
      _garminHttpVerbose(
        'POST $syncUri ($logLabel, timeout ${timeout.inSeconds}s)',
      );
      final sw = Stopwatch()..start();
      final response = await _http
          .post(syncUri, headers: _jsonHeaders, body: jsonEncode({'uid': uid}))
          .timeout(timeout);
      _garminTraceHttpResponse(
        label: logLabel,
        uri: syncUri,
        method: 'POST',
        response: response,
        elapsedMs: sw.elapsedMilliseconds,
        requestHeaders: _jsonHeaders,
      );
      final sc = response.statusCode;
      if (sc == 200) {
        _garminHttpVerbose('POST $path <- $sc in ${sw.elapsedMilliseconds}ms');
      } else {
        _garminHttpDiag(
          'POST $path <- $sc in ${sw.elapsedMilliseconds}ms baseUrl=$baseUrl '
          'body=${_responseBodySnippet(response.body)}',
        );
      }

      if (sc >= 500 && sc < 600) {
        throw Exception('Server unavailable');
      }

      final body = response.body.trim();
      final data = body.isEmpty
          ? <String, dynamic>{}
          : jsonDecode(body) as Map<String, dynamic>;

      if (sc == 200 && data['success'] == true) {
        return {
          'success': true,
          'message': data['message']?.toString() ?? 'Sync Garmin completata.',
        };
      }

      return {
        'success': false,
        'message':
            data['detail']?.toString() ??
            data['message']?.toString() ??
            _connectFailureUserMessage(
              statusCode: sc,
              baseUrl: baseUrl,
              body: response.body,
              serverDetail: null,
            ),
      };
    }

    try {
      return await doRequest();
    } on TimeoutException catch (e) {
      _invalidateBaseUrlCacheOnNetworkFailure(e);
      _garminHttpDiag(
        '$logLabel TIMEOUT (tentativo 1) baseUrl risolto al retry',
      );
      await Future<void>.delayed(const Duration(seconds: 3));
      try {
        return await doRequest();
      } on TimeoutException catch (e2) {
        _invalidateBaseUrlCacheOnNetworkFailure(e2);
        _garminHttpDiag('$logLabel TIMEOUT (tentativo 2)');
        return {
          'success': false,
          'message':
              'La sync Garmin sta impiegando troppo tempo. Riprova tra poco.',
        };
      } on Exception catch (e) {
        _invalidateBaseUrlCacheOnNetworkFailure(e);
        final msg = e.toString().toLowerCase();
        _garminHttpDiag('$logLabel errore dopo retry: $e');
        return {
          'success': false,
          'message': msg.contains('socket') || msg.contains('connection')
              ? 'Mini-server Garmin non raggiungibile.'
              : 'Errore di rete durante la sync Garmin.',
        };
      }
    } on Exception catch (e) {
      _invalidateBaseUrlCacheOnNetworkFailure(e);
      final msg = e.toString().toLowerCase();
      final isRetryable =
          msg.contains('socket') ||
          msg.contains('connection') ||
          msg.contains('timeout') ||
          msg.contains('unavailable');
      _garminHttpDiag('$logLabel eccezione: $e (retry=$isRetryable)');
      if (isRetryable) {
        await Future<void>.delayed(const Duration(seconds: 3));
        try {
          return await doRequest();
        } on Exception catch (e2) {
          _invalidateBaseUrlCacheOnNetworkFailure(e2);
          final m2 = e2.toString().toLowerCase();
          _garminHttpDiag('$logLabel errore tentativo 2: $e2');
          return {
            'success': false,
            'message': m2.contains('socket') || m2.contains('connection')
                ? 'Mini-server Garmin non raggiungibile.'
                : 'Errore di rete durante la sync Garmin.',
          };
        }
      }
      return {
        'success': false,
        'message': msg.contains('socket') || msg.contains('connection')
            ? 'Mini-server Garmin non raggiungibile.'
            : 'Errore di rete durante la sync Garmin.',
      };
    }
  }
}
