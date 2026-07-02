import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart'
    show debugPrint, kDebugMode, visibleForTesting;
import 'package:http/http.dart' as http;

/// Client OAuth1 puro‑Dart per lo scambio **ticket → token** Garmin, equivalente
/// a `garth/sso.py` (`get_oauth1_token` + `exchange`).
///
/// Usato SOLO su piattaforme **native** (Windows/desktop/mobile): lì non c'è CORS
/// e le chiamate a `connectapi.garmin.com` sono autenticate via **firma OAuth1**
/// (nessun cookie di sessione, nessuno scraping CSRF, nessuna gestione MFA — il
/// login vero avviene sulla pagina di Garmin nella WebView).
///
/// Il token prodotto da [buildGarthTokenB64] è byte‑compatibile con
/// `garth.http.Client.dumps()` — `base64(json([oauth1, oauth2]))` — così
/// `garmin-sync-server` può rileggerlo/rinnovarlo per le sync.
class GarminOAuth1Client {
  GarminOAuth1Client({http.Client? httpClient})
    : _http = httpClient ?? http.Client();

  final http.Client _http;

  static const String _domain = 'garmin.com';

  /// User‑Agent atteso da Garmin per il flusso OAuth1 mobile (come garth).
  static const String _userAgent = 'com.garmin.android.apps.connectmobile';

  /// Consumer key/secret pubblici di Garmin Connect mobile (come garth).
  static const String _consumerUrl =
      'https://thegarth.s3.amazonaws.com/oauth_consumer.json';
  static const String _fallbackConsumerKey =
      'fc3e99d2-118c-44b8-8ae3-03370dde24c0';
  static const String _fallbackConsumerSecret =
      'E08WAR897WEy2knn7aFBrvegVAf0AFdWBBF';

  static const Duration _httpTimeout = Duration(seconds: 30);

  String? _consumerKey;
  String? _consumerSecret;

  Future<void> _ensureConsumer() async {
    if (_consumerKey != null && _consumerSecret != null) return;
    try {
      final resp = await _http
          .get(Uri.parse(_consumerUrl))
          .timeout(const Duration(seconds: 15));
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        final k = (data['consumer_key'] as String?)?.trim();
        final s = (data['consumer_secret'] as String?)?.trim();
        if (k != null && k.isNotEmpty && s != null && s.isNotEmpty) {
          _consumerKey = k;
          _consumerSecret = s;
          return;
        }
      }
    } on Object catch (e) {
      if (kDebugMode) {
        debugPrint(
          '[GarminOAuth1] consumer da S3 non disponibile: $e -> fallback',
        );
      }
    }
    _consumerKey = _fallbackConsumerKey;
    _consumerSecret = _fallbackConsumerSecret;
  }

  /// Passo 1 — `GET .../preauthorized`: dal ticket CAS ottiene l'OAuth1 token
  /// (`oauth_token`, `oauth_token_secret`, ed eventuale `mfa_token`).
  ///
  /// [loginUrl] deve coincidere col `service` usato per emettere il ticket
  /// (nel flusso nativo: `https://sso.garmin.com/sso/embed`).
  Future<Map<String, String>> getOAuth1Token({
    required String ticket,
    required String loginUrl,
  }) async {
    await _ensureConsumer();
    const base =
        'https://connectapi.$_domain/oauth-service/oauth/preauthorized';
    final params = <String, String>{
      'ticket': ticket,
      'login-url': loginUrl,
      'accepts-mfa-tokens': 'true',
    };
    final authHeader = _authHeader(
      method: 'GET',
      baseUrl: base,
      requestParams: params,
    );
    final query = params.entries
        .map((e) => '${_enc(e.key)}=${_enc(e.value)}')
        .join('&');
    final resp = await _http
        .get(
          Uri.parse('$base?$query'),
          headers: {'Authorization': authHeader, 'User-Agent': _userAgent},
        )
        .timeout(_httpTimeout);
    if (resp.statusCode != 200) {
      throw GarminOAuth1Exception(
        'preauthorized HTTP ${resp.statusCode}: ${_snippet(resp.body)}',
      );
    }
    final parsed = Uri.splitQueryString(resp.body.trim());
    final oauthToken = parsed['oauth_token'];
    final oauthTokenSecret = parsed['oauth_token_secret'];
    if (oauthToken == null ||
        oauthToken.isEmpty ||
        oauthTokenSecret == null ||
        oauthTokenSecret.isEmpty) {
      throw GarminOAuth1Exception(
        'preauthorized: risposta senza oauth_token/secret (${_snippet(resp.body)})',
      );
    }
    final out = <String, String>{
      'oauth_token': oauthToken,
      'oauth_token_secret': oauthTokenSecret,
    };
    final mfa = parsed['mfa_token'];
    if (mfa != null && mfa.isNotEmpty) out['mfa_token'] = mfa;
    return out;
  }

  /// Passo 2 — `POST .../exchange/user/2.0`: scambia l'OAuth1 token con
  /// l'OAuth2 token (JSON) usato per le chiamate API Garmin.
  Future<Map<String, dynamic>> exchange(Map<String, String> oauth1) async {
    await _ensureConsumer();
    const base =
        'https://connectapi.$_domain/oauth-service/oauth/exchange/user/2.0';
    final bodyParams = <String, String>{};
    final mfa = oauth1['mfa_token'];
    if (mfa != null && mfa.isNotEmpty) bodyParams['mfa_token'] = mfa;
    final authHeader = _authHeader(
      method: 'POST',
      baseUrl: base,
      requestParams: bodyParams,
      token: oauth1['oauth_token'],
      tokenSecret: oauth1['oauth_token_secret'],
    );
    final body = bodyParams.entries
        .map((e) => '${_enc(e.key)}=${_enc(e.value)}')
        .join('&');
    final resp = await _http
        .post(
          Uri.parse(base),
          headers: {
            'Authorization': authHeader,
            'User-Agent': _userAgent,
            'Content-Type': 'application/x-www-form-urlencoded',
          },
          body: body,
        )
        .timeout(_httpTimeout);
    if (resp.statusCode != 200) {
      throw GarminOAuth1Exception(
        'exchange HTTP ${resp.statusCode}: ${_snippet(resp.body)}',
      );
    }
    final data = jsonDecode(resp.body);
    if (data is! Map<String, dynamic>) {
      throw GarminOAuth1Exception(
        'exchange: risposta non JSON‑oggetto (${_snippet(resp.body)})',
      );
    }
    return data;
  }

  /// Costruisce il token base64 nel formato di `garth.http.Client.dumps()`:
  /// `base64(json([oauth1_dict, oauth2_dict]))`.
  ///
  /// Scrive **solo** i campi previsti dai dataclass di garth (`OAuth1Token` /
  /// `OAuth2Token`): eventuali chiavi extra nella risposta di Garmin vengono
  /// scartate così `loads()` sul server non fallisce.
  String buildGarthTokenB64({
    required Map<String, String> oauth1,
    required Map<String, dynamic> oauth2Raw,
  }) {
    final nowSec = DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000;
    final expiresIn = (oauth2Raw['expires_in'] as num?)?.toInt() ?? 0;
    final refreshExpiresIn =
        (oauth2Raw['refresh_token_expires_in'] as num?)?.toInt() ?? 0;

    final oauth1Dict = <String, dynamic>{
      'oauth_token': oauth1['oauth_token'],
      'oauth_token_secret': oauth1['oauth_token_secret'],
      'mfa_token': oauth1['mfa_token'],
      'mfa_expiration_timestamp': null,
      'domain': _domain,
    };
    final oauth2Dict = <String, dynamic>{
      'scope': oauth2Raw['scope'],
      'jti': oauth2Raw['jti'],
      'token_type': oauth2Raw['token_type'],
      'access_token': oauth2Raw['access_token'],
      'refresh_token': oauth2Raw['refresh_token'],
      'expires_in': expiresIn,
      'expires_at':
          (oauth2Raw['expires_at'] as num?)?.toInt() ?? nowSec + expiresIn,
      'refresh_token_expires_in': refreshExpiresIn,
      'refresh_token_expires_at':
          (oauth2Raw['refresh_token_expires_at'] as num?)?.toInt() ??
          nowSec + refreshExpiresIn,
    };
    return base64.encode(utf8.encode(jsonEncode([oauth1Dict, oauth2Dict])));
  }

  // --- Firma OAuth1 (HMAC‑SHA1, RFC 5849) ---

  String _authHeader({
    required String method,
    required String baseUrl,
    required Map<String, String> requestParams,
    String? token,
    String? tokenSecret,
  }) {
    final oauthParams = <String, String>{
      'oauth_consumer_key': _consumerKey!,
      'oauth_nonce': _nonce(),
      'oauth_signature_method': 'HMAC-SHA1',
      'oauth_timestamp': (DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000)
          .toString(),
      'oauth_version': '1.0',
    };
    if (token != null && token.isNotEmpty) oauthParams['oauth_token'] = token;

    // La base string della firma include gli oauth_* + i parametri di query/body.
    final signature = _sign(
      method: method,
      baseUrl: baseUrl,
      params: <String, String>{...oauthParams, ...requestParams},
      tokenSecret: tokenSecret ?? '',
    );
    oauthParams['oauth_signature'] = signature;

    final header = oauthParams.entries
        .map((e) => '${_enc(e.key)}="${_enc(e.value)}"')
        .join(', ');
    return 'OAuth $header';
  }

  String _sign({
    required String method,
    required String baseUrl,
    required Map<String, String> params,
    required String tokenSecret,
  }) => oauth1Signature(
    method: method,
    baseUrl: baseUrl,
    params: params,
    consumerSecret: _consumerSecret!,
    tokenSecret: tokenSecret,
  );

  /// Firma OAuth1 HMAC‑SHA1 (RFC 5849): `base64(HMAC-SHA1(signingKey, baseString))`.
  /// [params] deve già contenere sia gli `oauth_*` sia i parametri di query/body.
  /// Puro e deterministico (nessun nonce/timestamp interni) → testabile con i
  /// vettori OAuth1 noti.
  @visibleForTesting
  static String oauth1Signature({
    required String method,
    required String baseUrl,
    required Map<String, String> params,
    required String consumerSecret,
    required String tokenSecret,
  }) {
    final encoded = <String, String>{
      for (final e in params.entries) _enc(e.key): _enc(e.value),
    };
    final sortedKeys = encoded.keys.toList()..sort();
    final paramString = sortedKeys.map((k) => '$k=${encoded[k]}').join('&');
    final baseString = '$method&${_enc(baseUrl)}&${_enc(paramString)}';
    final signingKey = '${_enc(consumerSecret)}&${_enc(tokenSecret)}';
    final digest = Hmac(
      sha1,
      utf8.encode(signingKey),
    ).convert(utf8.encode(baseString));
    return base64.encode(digest.bytes);
  }

  String _nonce() {
    final rnd = Random.secure();
    final bytes = List<int>.generate(16, (_) => rnd.nextInt(256));
    return base64.encode(bytes).replaceAll(RegExp(r'[^A-Za-z0-9]'), '');
  }

  /// Percent‑encoding RFC 3986: unreserved = `A‑Z a‑z 0‑9 - . _ ~`; tutto il
  /// resto in `%HH` maiuscolo. Applicato **sia** alla firma **sia** alla query
  /// trasmessa, così i valori firmati e quelli inviati coincidono.
  static String _enc(String input) {
    final bytes = utf8.encode(input);
    final sb = StringBuffer();
    for (final b in bytes) {
      final isUnreserved =
          (b >= 0x41 && b <= 0x5A) || // A‑Z
          (b >= 0x61 && b <= 0x7A) || // a‑z
          (b >= 0x30 && b <= 0x39) || // 0‑9
          b == 0x2D || // -
          b == 0x2E || // .
          b == 0x5F || // _
          b == 0x7E; // ~
      if (isUnreserved) {
        sb.writeCharCode(b);
      } else {
        sb
          ..write('%')
          ..write(b.toRadixString(16).toUpperCase().padLeft(2, '0'));
      }
    }
    return sb.toString();
  }

  static String _snippet(String body, {int max = 300}) {
    final t = body.trim().replaceAll(RegExp(r'\s+'), ' ');
    return t.length <= max ? t : '${t.substring(0, max)}…';
  }
}

class GarminOAuth1Exception implements Exception {
  GarminOAuth1Exception(this.message);
  final String message;
  @override
  String toString() => 'GarminOAuth1Exception: $message';
}
