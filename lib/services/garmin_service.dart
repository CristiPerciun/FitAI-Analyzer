import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart'
    show debugPrint, kDebugMode, visibleForTesting;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../models/fitness_data.dart';
import '../utils/platform_firestore_fix.dart';

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
          if (loginUrl != null) 'loginUrl': loginUrl,
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
