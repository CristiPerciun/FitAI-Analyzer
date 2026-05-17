import 'dart:async';
import 'dart:convert';

import 'package:fitai_analyzer/utils/comm_fitai_server_json_detail.dart';

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

/// `flutter run -d chrome` / web-server su **http://localhost**: probe LAN verso il Pi è permesso.
/// Su **https** (PWA / GitHub Pages) restituisce false: li usiamo solo REMOTE per evitare mixed content.
bool _isGarminWebLocalHttpDevHost(Uri? page) {
  if (page == null) return false;
  if (page.scheme.toLowerCase() != 'http') return false;
  final h = page.host.toLowerCase();
  return h == 'localhost' ||
      h == '127.0.0.1' ||
      h == '[::1]' ||
      h.endsWith('.localhost');
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

  /// Da una pagina web **HTTPS** (hosting / PWA) il browser blocca `fetch`/`XHR`
  /// verso server **HTTP** (mixed active content). Forza l’URL pubblico HTTPS
  /// (`GARMIN_SERVER_URL_REMOTE`) quando serve OAuth / sync dal browser.
  String _upgradeHttpSyncOriginForHttpsWebApp(String candidate) {
    if (!kIsWeb) return candidate;
    final page = garmin_web.garminWebCurrentUri();
    if (page == null) return candidate;
    if (page.scheme.toLowerCase() != 'https') return candidate;
    final u = Uri.tryParse(candidate.trim());
    if (u == null || u.scheme.toLowerCase() != 'http') return candidate;
    final remote = _garminServerUrlRemote;
    _garminHttpDiag(
      'Web HTTPS (${page.origin}): il mini-server su HTTP ($candidate) è '
      'bloccato dal browser (mixed content). Uso HTTPS pubblico: $remote. '
      'Configura GARMIN_SERVER_URL_REMOTE / HTTPS sul Pi o PUBLIC_SERVER_URL sul server.',
    );
    return remote;
  }

  /// Risolve URL: prova LAN prima (192.168.1.200:8080), se fallisce usa REMOTE (DuckDNS).
  /// A casa: LAN raggiungibile. Fuori: solo REMOTE.
  /// Se GARMIN_SERVER_URL e' impostato, usa solo quello (override).
  Future<String> _resolveBaseUrl() async {
    final resolved = await _resolveBaseUrlUnadjusted();
    return _upgradeHttpSyncOriginForHttpsWebApp(resolved);
  }

  Future<String> _resolveBaseUrlUnadjusted() async {
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

    /// `flutter run`/web-server su **http://localhost**: qui ha senso il probe LAN verso il Pi in rete locale.
    /// Su **HTTPS** (GitHub Pages) evitiamo LAN: spesso è solo HTTP (mixed content) e 3s di timeout
    /// rovinano lo scambio ticket Garmin.
    final webDevHttpLocalhost = kIsWeb &&
        _isGarminWebLocalHttpDevHost(garmin_web.garminWebCurrentUri());

    if (kIsWeb) {
      if (_cachedBaseUrl != null) {
        final c = _cachedBaseUrl!;
        if (c == lan && !webDevHttpLocalhost) {
          _garminHttpDiag(
            'Web HTTPS: cache LAN ignorata -> REMOTE ($remote) (OAuth/ticket time-sensitive)',
          );
          _cachedBaseUrl = remote;
          return remote;
        }
        _garminHttpVerbose('Web: cache base URL -> $c');
        return c;
      }
      if (webDevHttpLocalhost) {
        _garminHttpVerbose(
          'Web localhost HTTP: probe LAN ${_lanProbeTimeout.inSeconds}s: $lan '
          '(se timeout -> $remote)',
        );
        try {
          final sw = Stopwatch()..start();
          final r = await _http.get(Uri.parse('$lan/')).timeout(_lanProbeTimeout);
          _garminTraceHttpResponse(
            label: 'resolveBaseUrl Web local LAN probe',
            uri: Uri.parse('$lan/'),
            method: 'GET',
            response: r,
            elapsedMs: sw.elapsedMilliseconds,
          );
          if (r.statusCode == 200) {
            _cachedBaseUrl = lan;
            _garminHttpVerbose(
              'Web localhost: LAN OK (${sw.elapsedMilliseconds}ms) -> $lan',
            );
            return lan;
          }
          _garminHttpVerbose('Web localhost: LAN HTTP ${r.statusCode} -> REMOTE');
        } on Object catch (e) {
          _garminHttpVerbose('Web localhost: LAN non disponibile: $e -> REMOTE');
        }
        _cachedBaseUrl = remote;
        _garminHttpVerbose('Web localhost: base finale -> $remote');
        return remote;
      }
      _cachedBaseUrl = remote;
      _garminHttpVerbose(
        'Web HTTPS: REMOTE senza probe LAN -> $remote '
        '(in dev locale usa http://localhost; per URL forzato usa GARMIN_SERVER_URL in .env)',
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

  /// Dopo il CAS sul Pi: redirect a `/?garmin_oauth=ok` o `garmin_oauth_err=…`.
  Map<String, dynamic>? consumeGarminWebServerCasRedirectQuery() {
    if (!kIsWeb) return null;
    final raw = garmin_web.garminWebConsumeServerCasOAuthQuery();
    if (raw == null) return null;
    if (raw['status'] == 'ok') {
      return {'success': true, 'message': ''};
    }
    if (raw['status'] == 'error') {
      return {
        'success': false,
        'message': raw['message'] ?? 'Errore Garmin OAuth.',
      };
    }
    return null;
  }

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

  /// Ultimo URL base del Pi risolto (LAN o REMOTE), già normalizzato; `null` se mai risolto.
  /// Usato dal dialog Garmin per passare l'`api_base` come query string al ponte `garmin_oauth_prepare.html`.
  String? get lastResolvedServerBaseUrlForWebBridge {
    final c = _cachedBaseUrl;
    if (c == null || c.isEmpty) return null;
    return normalizeGarminServerBaseUrl(c);
  }

  /// Scrive in `sessionStorage` i dati per `web/garmin_oauth_prepare.html`.
  ///
  /// Il dialog Garmin chiama questo all’apertura (con `await`): al tap la navigazione
  /// verso la pagina ponte è **sincrona** e rispetta le gesture policy di WebKit (iOS).
  Future<void> primeGarminWebSsoBridge({required String uid}) async {
    if (!kIsWeb) return;
    final u = uid.trim();
    if (u.isEmpty) {
      throw ArgumentError.value(uid, 'uid', 'uid non valido');
    }
    final base = await _resolveBaseUrl();
    final normalized = normalizeGarminServerBaseUrl(base);
    garmin_web.garminWebSessionSet('garmin_oauth_bridge_uid', u);
    garmin_web.garminWebSessionSet('garmin_oauth_bridge_api_base', normalized);
    final auth = _jsonHeaders['Authorization']?.trim();
    if (auth != null && auth.isNotEmpty) {
      garmin_web.garminWebSessionSet('garmin_oauth_bridge_authorization', auth);
    } else {
      garmin_web.garminWebSessionRemove('garmin_oauth_bridge_authorization');
    }
    _garminOAuthWebLog(
      'primeGarminWebSsoBridge: api_base=$normalized bearer=${auth != null && auth.isNotEmpty}',
    );
  }

  /// SSO Garmin su web (tutte le piattaforme: desktop, Android, iPhone, iPad, PWA).
  ///
  /// **Mai più popup**: su iOS / WebKit il popup perdeva `postMessage` e `localStorage`
  /// per partizionamento; su desktop poteva apparire prima la popup e poi cadere nel
  /// fallback full-page, generando il "doppio flusso" segnalato dall'utente.
  /// Si usa **sempre** `prepare` + navigazione full-page (`_garminSsoWebFullPageWithPrepare`).
  ///
  /// Nota: da hosting **HTTPS** non è possibile chiamare un mini-server solo **HTTP**
  /// (mixed content): `_resolveBaseUrl()` forza l'URL remoto HTTPS se necessario.
  Future<Map<String, dynamic>> connectViaGarminSsoWeb({
    required String uid,
  }) async {
    if (!kIsWeb) {
      return {'success': false, 'message': 'Metodo solo per web.'};
    }
    final currentHref = garmin_web.garminWebCurrentUri()?.toString() ?? '(n/a)';
    _garminOAuthWebLog(
      'connectViaGarminSsoWeb: uid=$uid bearer=${_jsonHeaders['Authorization']?.trim().isNotEmpty == true}',
    );
    _garminOAuthWebLog('connectViaGarminSsoWeb: window.href=$currentHref');
    return _garminSsoWebFullPageWithPrepare(uid: uid);
  }

  /// Navigazione **full-page** verso Garmin CAS dopo `connect3PrepareWebSso` (state server-side).
  ///
  /// Ritorna `web_redirect: true` prima di `location.assign`: dopo il login Garmin il browser
  /// passa dal Pi (`/garmin/connect3/web-sso/cas-callback`) e torna all'app con `?garmin_oauth=…`.
  /// Restano [completeGarminWebOAuthIfPresent] (ticket su stesso host) e
  /// [consumeGarminWebOAuthSessionResult] (`garmin_oauth_return.html` legacy).
  Future<Map<String, dynamic>> _garminSsoWebFullPageWithPrepare({
    required String uid,
  }) async {
    final prep = await connect3PrepareWebSso(
      uid: uid,
      appReturnBase: garmin_web.garminWebAppReturnBaseUri().toString(),
    );
    if (prep['success'] != true) {
      final rawMsg = prep['message']?.toString().trim() ?? '';
      final msg = rawMsg.isNotEmpty
          ? rawMsg
          : 'Impossibile avviare OAuth Garmin (prepare fallito). Aggiorna garmin-sync-server e PUBLIC_SERVER_URL.';
      _garminOAuthWebLog('_garminSsoWebFullPageWithPrepare: prepare failed message=$msg');
      return {'success': false, 'message': msg};
    }

    final state = prep['state']?.toString().trim() ?? '';
    final originRaw = prep['public_origin']?.toString().trim() ?? '';
    if (state.isEmpty || originRaw.isEmpty) {
      return {
        'success': false,
        'message':
            'Risposta prepare Garmin incompleta (state/public_origin). Aggiorna garmin-sync-server.',
      };
    }
    final gxApi = normalizeGarminServerBaseUrl(originRaw);
    final authHeader = _jsonHeaders['Authorization']?.trim() ?? '';

    garmin_web.garminWebSessionSet('garmin_oauth_sso_state', state);
    garmin_web.garminWebSessionSet('garmin_oauth_sso_gx_api', gxApi);

    final callbackUrl = Uri.parse(
      '$gxApi/garmin/connect3/web-sso/cas-callback?state=${Uri.encodeQueryComponent(state)}',
    ).toString();
    final ssoUrl = buildGarminPopupSsoLoginUrl(callbackUrl);

    if (authHeader.isNotEmpty) {
      garmin_web.garminWebSessionSet('garmin_oauth_auth', authHeader);
    } else {
      garmin_web.garminWebSessionRemove('garmin_oauth_auth');
    }
    garmin_web.garminWebSessionRemove('garmin_oauth_uid');
    garmin_web.garminWebSessionRemove('garmin_oauth_base_url');

    _garminHttpVerbose('Web SSO full-page: navigazione → $ssoUrl');
    _garminOAuthWebLog('full-page callback(service)=$callbackUrl');
    _garminOAuthWebLog('ssoUrl=$ssoUrl');
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

  Future<bool> isMiFitnessConnected(String uid) async {
    final doc = await _firestore.collection('users').doc(uid).get();
    return doc.data()?['mi_fitness_linked'] == true;
  }

  /// Collega Mi Fitness (credenziali una tantum sul server → solo token su Firestore).
  /// [region]: `eu` (default) usa prima cluster EU/Zepp EU2; `us` per account non europei.
  Future<Map<String, dynamic>> connectMiFitness({
    required String uid,
    required String email,
    required String password,
    String region = 'eu',
  }) async {
    final baseUrl = await _resolveBaseUrl();
    final uri = Uri.parse('$baseUrl/mi-fitness/connect');
    try {
      final sw = Stopwatch()..start();
      final response = await _http
          .post(
            uri,
            headers: _jsonHeaders,
            body: jsonEncode({
              'uid': uid,
              'email': email.trim(),
              'password': password,
              'region': region,
            }),
          )
          .timeout(const Duration(seconds: 90));
      _garminTraceHttpResponse(
        label: 'mi-fitness/connect',
        uri: uri,
        method: 'POST',
        response: response,
        elapsedMs: sw.elapsedMilliseconds,
        requestHeaders: _jsonHeaders,
        omitBody: true,
      );
      final st = response.statusCode;
      final data = _tryDecodeJsonObject(response.body) ?? {};
      if (st == 200 && data['success'] == true) {
        return {
          'success': true,
          'message': data['message']?.toString() ?? 'Mi Fitness collegato.',
        };
      }
      final detail = commFitaiServerDetailOrMessage(data);
      if (detail.isNotEmpty) {
        return {'success': false, 'message': detail};
      }
      return {
        'success': false,
        'message': _connectFailureUserMessage(
          statusCode: st,
          baseUrl: baseUrl,
          body: response.body,
          serverDetail: null,
        ),
      };
    } on TimeoutException catch (e) {
      _invalidateBaseUrlCacheOnNetworkFailure(e);
      return {'success': false, 'message': 'Timeout durante connessione Mi Fitness.'};
    } on Exception catch (e) {
      _invalidateBaseUrlCacheOnNetworkFailure(e);
      return {'success': false, 'message': 'Errore di rete: $e'};
    }
  }

  Future<Map<String, dynamic>> disconnectMiFitness({required String uid}) async {
    final baseUrl = await _resolveBaseUrl();
    final uri = Uri.parse('$baseUrl/mi-fitness/disconnect');
    try {
      final sw = Stopwatch()..start();
      final response = await _http
          .post(uri, headers: _jsonHeaders, body: jsonEncode({'uid': uid}))
          .timeout(const Duration(seconds: 30));
      _garminTraceHttpResponse(
        label: 'mi-fitness/disconnect',
        uri: uri,
        method: 'POST',
        response: response,
        elapsedMs: sw.elapsedMilliseconds,
        requestHeaders: _jsonHeaders,
      );
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode == 200 && data['success'] == true) {
        return {
          'success': true,
          'message': data['message']?.toString() ?? 'Mi Fitness scollegato.',
        };
      }
      return {
        'success': false,
        'message': data['detail']?.toString() ?? 'Disconnessione non riuscita.',
      };
    } on TimeoutException catch (e) {
      _invalidateBaseUrlCacheOnNetworkFailure(e);
      return {'success': false, 'message': 'Server non risponde. Riprova.'};
    } on Exception catch (e) {
      _invalidateBaseUrlCacheOnNetworkFailure(e);
      return {'success': false, 'message': 'Errore di rete: $e'};
    }
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

  /// Registra una sessione OAuth web (state server-side) prima del redirect Garmin CAS.
  Future<Map<String, dynamic>> connect3PrepareWebSso({
    required String uid,
    String? appReturnBase,
  }) async {
    final body = <String, dynamic>{'uid': uid};
    final arb = appReturnBase?.trim();
    if (arb != null && arb.isNotEmpty) {
      body['app_return_base'] = arb;
    }
    return _connect2Post(
      path: '/garmin/connect3/web-sso/prepare',
      body: body,
      logLabel: 'garmin/connect3/web-sso/prepare',
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
        final extractedLoginUrl =
            (data['loginUrl'] is String &&
                (data['loginUrl'] as String).isNotEmpty)
            ? data['loginUrl'] as String
            : _extractGarminLoginUrl(message);
        final out = <String, dynamic>{
          'success': data['success'] == true,
          'message': message,
          if (data['mfaRequired'] == true) 'mfaRequired': true,
          if (data['loginSessionId'] is String)
            'loginSessionId': data['loginSessionId'],
          if (extractedLoginUrl != null && extractedLoginUrl.isNotEmpty)
            'loginUrl': extractedLoginUrl,
        };
        final st = data['state'];
        if (st is String && st.trim().isNotEmpty) out['state'] = st.trim();
        final po = data['public_origin'];
        if (po is String && po.trim().isNotEmpty) {
          out['public_origin'] = normalizeGarminServerBaseUrl(po.trim());
        }
        return out;
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
    List<String> sources = const ['garmin', 'strava', 'mi_fitness'],
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
