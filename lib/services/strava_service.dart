import 'dart:convert';

import 'package:flutter/foundation.dart'
    show debugPrint, kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_web_auth_2/flutter_web_auth_2.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import 'strava_desktop_stub.dart'
    if (dart.library.io) 'strava_desktop_io.dart'
    as desktop;
import 'strava_oauth_callback.dart';
import 'strava_oauth_credentials_service.dart';
import 'strava_web_oauth_stub.dart'
    if (dart.library.html) 'strava_web_oauth_web.dart'
    as strava_web;

import '../models/fitness_data.dart';
import 'garmin_service.dart';
import '../utils/activity_hr_series.dart';

final stravaServiceProvider = Provider<StravaService>((ref) => StravaService());

/// Su web, dopo [strava_web.stravaWebAssignLocation] verso Strava il browser esce;
/// il flusso riprende al reload con `?code=` (gestito da [StravaService.completeWebOAuthIfPresent]).
class StravaWebOAuthRedirectPending implements Exception {
  const StravaWebOAuthRedirectPending();
}

// ==================== MODELLO DETTAGLIATO ====================
class StravaActivity {
  final int id;
  final String name;
  final String sportType;
  final double distance; // metri
  final int movingTime;
  final int elapsedTime;
  final double elevationGain;
  final double? avgSpeed; // m/s
  final double? avgHeartrate;
  final double? maxHeartrate;
  final String? deviceName;
  final String startDate;
  final String? summaryPolyline;
  final double? calories; // solo da detailed
  final List<dynamic>? laps; // solo da detailed
  final Map<String, dynamic>? _raw; // payload API (lista/dettaglio)

  StravaActivity({
    required this.id,
    required this.name,
    required this.sportType,
    required this.distance,
    required this.movingTime,
    required this.elapsedTime,
    required this.elevationGain,
    this.avgSpeed,
    this.avgHeartrate,
    this.maxHeartrate,
    this.deviceName,
    required this.startDate,
    this.summaryPolyline,
    this.calories,
    this.laps,
    Map<String, dynamic>? raw,
  }) : _raw = raw;

  factory StravaActivity.fromJson(
    Map<String, dynamic> json, {
    bool detailed = false,
  }) {
    final map = json['map'] as Map<String, dynamic>?;
    return StravaActivity(
      id: json['id'] as int,
      name: json['name'] ?? 'Attività senza nome',
      sportType: json['sport_type'] ?? json['type'] ?? 'Unknown',
      distance: (json['distance'] ?? 0).toDouble(),
      movingTime: json['moving_time'] ?? 0,
      elapsedTime: json['elapsed_time'] ?? 0,
      elevationGain: (json['total_elevation_gain'] ?? 0).toDouble(),
      avgSpeed: (json['average_speed'] as num?)?.toDouble(),
      avgHeartrate: (json['average_heartrate'] as num?)?.toDouble(),
      maxHeartrate: (json['max_heartrate'] as num?)?.toDouble(),
      deviceName: json['device_name'],
      startDate: json['start_date'] ?? json['start_date_local'] ?? '',
      summaryPolyline: map?['summary_polyline'],
      calories: detailed ? (json['calories'] as num?)?.toDouble() : null,
      laps: detailed ? json['laps'] : null,
      raw: json,
    );
  }

  /// Da FitnessData (Firestore) per visualizzazione lista
  factory StravaActivity.fromFitnessData(FitnessData d) {
    final raw = d.stravaRaw ?? d.miFitnessRaw ?? d.raw ?? {};
    var idStr = d.stravaActivityId ?? '';
    if (idStr.isEmpty &&
        d.miFitnessTrackId != null &&
        d.miFitnessTrackId!.isNotEmpty) {
      idStr = d.miFitnessTrackId!;
    }
    if (idStr.isEmpty && d.id.startsWith('strava_')) {
      idStr = d.id.replaceFirst('strava_', '');
    }
    if (idStr.isEmpty && d.id.startsWith('mi_fitness_')) {
      idStr = d.id.replaceFirst('mi_fitness_', '');
    }
    return StravaActivity(
      id: int.tryParse(idStr) ?? 0,
      name: d.stravaActivityName ?? 'Attività',
      sportType: d.stravaActivityType,
      distance: (d.distanceKm ?? 0) * 1000,
      movingTime: ((d.activeMinutes ?? 0) * 60).round(),
      elapsedTime: (d.stravaElapsedMinutes * 60).round(),
      elevationGain: d.stravaElevationGainM ?? 0,
      avgSpeed: d.stravaAvgSpeedKmh != null ? d.stravaAvgSpeedKmh! / 3.6 : null,
      avgHeartrate: d.stravaAvgHeartrate,
      maxHeartrate: d.stravaMaxHeartrate,
      deviceName: d.stravaDeviceName,
      startDate: d.date.toIso8601String(),
      summaryPolyline: (raw['map'] as Map?)?['summary_polyline'],
      calories: d.calories,
      laps: null,
    );
  }

  /// Risposta grezza API (se presente), utile per debug o future feature.
  Map<String, dynamic>? get stravaRawJson => _raw;
}

class StravaService {
  /// Redirect URI per OAuth. In Strava (strava.com/settings/api) imposta
  /// "Authorization Callback Domain" = strava (host di myhealthsync://strava/callback)
  static const String redirectUri = 'myhealthsync://strava/callback';
  static const String callbackScheme = 'myhealthsync';

  static const String _sessionOAuthState = 'fitai_strava_oauth_state';
  static const String _sessionPendingRegister =
      'fitai_strava_pending_server_register';
  static const String _sessionClientId = 'fitai_strava_client_id';
  static const String _sessionRedirectUri = 'fitai_strava_redirect_uri';
  static const String _prefsClientId = 'strava_client_id';
  static const String _prefsClientSecret = 'strava_client_secret';

  static bool _webOAuthReturnHandled = false;

  /// Base URL di redirect per OAuth web (pulizia URL dopo OAuth, stesso host/path normalizzati).
  static Uri stravaWebRedirectBase(Uri loc) {
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

  /// `redirect_uri` per Strava su web (authorize + exchange): deve essere **identico** a quanto
  /// accettato in https://www.strava.com/settings/api (dominio + path + eventuale slash finale).
  ///
  /// Su PWA iPhone il [loc] può differire leggermente dal desktop (www vs bare, path): imposta
  /// `STRAVA_WEB_REDIRECT_URI` in `.env` (es. `https://tuodominio.it/`) uguale alla voce Strava.
  static String stravaOAuthWebRedirectUriString(Uri loc) {
    if (dotenv.isInitialized) {
      final raw = dotenv.env['STRAVA_WEB_REDIRECT_URI']?.trim();
      if (raw != null && raw.isNotEmpty) {
        final u = Uri.parse(raw);
        final path = u.path.isEmpty ? '/' : u.path;
        return Uri(
          scheme: u.scheme,
          userInfo: u.userInfo,
          host: u.host,
          port: u.hasPort ? u.port : null,
          path: path,
        ).toString();
      }
    }
    return stravaWebRedirectBase(loc).toString();
  }

  static Map<String, String> _webOAuthParams(Uri loc) {
    final params = <String, String>{...loc.queryParameters};
    var fragment = loc.fragment.trim();
    if (fragment.isEmpty) return params;

    final queryStart = fragment.indexOf('?');
    if (queryStart >= 0) {
      fragment = fragment.substring(queryStart + 1);
    }
    while (fragment.startsWith('#') ||
        fragment.startsWith('?') ||
        fragment.startsWith('&')) {
      fragment = fragment.substring(1);
    }
    if (fragment.isEmpty || !fragment.contains('=')) return params;

    try {
      params.addAll(Uri.splitQueryString(fragment));
    } on FormatException {
      // Il frammento può essere una route Flutter, non una query OAuth.
    }
    return params;
  }

  String? _accessToken;
  String? _refreshToken;
  String? _clientId;
  String? _clientSecret;
  DateTime? _expiresAt;

  Future<void> _loadInitialTokens() async {
    final prefs = await SharedPreferences.getInstance();
    _accessToken = prefs.getString('strava_access_token');
    _refreshToken = prefs.getString('strava_refresh_token');
    _clientId = prefs.getString(_prefsClientId);
    _clientSecret = prefs.getString(_prefsClientSecret);
    final expires = prefs.getInt('strava_expires_at');
    _expiresAt = expires != null
        ? DateTime.fromMillisecondsSinceEpoch(expires)
        : null;
  }

  /// Rimuove i token: revoca su Strava (deauthorize) e cancella in locale.
  Future<void> clearTokens() async {
    await _loadInitialTokens();
    if (_accessToken != null) {
      try {
        if (_isTokenExpired() && _refreshToken != null) {
          await _performTokenRefresh();
        }
        await http.post(
          Uri.parse(
            'https://www.strava.com/oauth/deauthorize',
          ).replace(queryParameters: {'access_token': _accessToken!}),
        );
      } catch (_) {
        // Revoca fallita (token già invalidato, offline, ecc.) - cancella comunque in locale
      }
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('strava_access_token');
    await prefs.remove('strava_refresh_token');
    await prefs.remove('strava_expires_at');
    await prefs.remove(_prefsClientId);
    await prefs.remove(_prefsClientSecret);
    _accessToken = null;
    _refreshToken = null;
    _clientId = null;
    _clientSecret = null;
    _expiresAt = null;
  }

  /// Verifica se Strava è collegato (token presente e valido o refreshabile).
  Future<bool> isConnected() async {
    await _loadInitialTokens();
    return _accessToken != null;
  }

  /// Dopo redirect Strava su web: scambia `code` via server (CORS) e pulisce l’URL.
  Future<bool> completeWebOAuthIfPresent({
    required GarminService garminService,
    required String uid,
  }) async {
    if (!kIsWeb || _webOAuthReturnHandled) {
      return false;
    }
    final loc = strava_web.stravaWebCurrentUri();
    if (loc == null) {
      return false;
    }

    final oauthParams = _webOAuthParams(loc);
    final err = oauthParams['error'];
    if (err != null) {
      _webOAuthReturnHandled = true;
      strava_web.stravaWebReplaceCleanUrl(stravaWebRedirectBase(loc));
      strava_web.stravaWebSessionRemove(_sessionOAuthState);
      strava_web.stravaWebSessionRemove(_sessionPendingRegister);
      strava_web.stravaWebSessionRemove(_sessionClientId);
      strava_web.stravaWebSessionRemove(_sessionRedirectUri);
      return false;
    }

    final code = oauthParams['code'];
    if (code == null || code.isEmpty) {
      return false;
    }

    final gotState = oauthParams['state'];
    final stored = strava_web.stravaWebSessionGet(_sessionOAuthState);
    if (stored == null ||
        stored.isEmpty ||
        gotState == null ||
        gotState != stored) {
      strava_web.stravaWebReplaceCleanUrl(stravaWebRedirectBase(loc));
      strava_web.stravaWebSessionRemove(_sessionOAuthState);
      strava_web.stravaWebSessionRemove(_sessionPendingRegister);
      strava_web.stravaWebSessionRemove(_sessionClientId);
      strava_web.stravaWebSessionRemove(_sessionRedirectUri);
      throw Exception(
        'Stato OAuth Strava non valido o sessione scaduta. Riprova a collegare Strava.',
      );
    }

    final clientId = strava_web.stravaWebSessionGet(_sessionClientId);
    if (clientId == null ||
        !StravaOAuthCredentialsService.isValidClientId(clientId)) {
      strava_web.stravaWebReplaceCleanUrl(stravaWebRedirectBase(loc));
      strava_web.stravaWebSessionRemove(_sessionOAuthState);
      strava_web.stravaWebSessionRemove(_sessionPendingRegister);
      strava_web.stravaWebSessionRemove(_sessionClientId);
      strava_web.stravaWebSessionRemove(_sessionRedirectUri);
      throw Exception(
        'Client ID Strava mancante nella sessione OAuth. Riprova a collegare Strava.',
      );
    }

    final redirectStr =
        strava_web.stravaWebSessionGet(_sessionRedirectUri) ??
        stravaOAuthWebRedirectUriString(loc);
    _webOAuthReturnHandled = true;
    try {
      final reg = await garminService.exchangeStravaOAuthCodeOnServer(
        uid: uid,
        code: code,
        redirectUri: redirectStr,
        clientId: clientId,
      );

      if (reg['success'] != true) {
        throw Exception(
          reg['message']?.toString() ??
              'Exchange OAuth Strava sul server fallito.',
        );
      }

      final access = reg['access_token'] as String?;
      final refresh = reg['refresh_token'] as String?;
      final expiresInRaw = reg['expires_in'];
      final expiresIn = expiresInRaw is int
          ? expiresInRaw
          : int.tryParse('$expiresInRaw') ?? 21600;
      if (access == null || refresh == null) {
        throw StateError('Risposta server Strava incompleta (token mancanti).');
      }

      await saveTokens(access, refresh, expiresIn, clientId: clientId);

      strava_web.stravaWebSessionRemove(_sessionOAuthState);
      strava_web.stravaWebSessionRemove(_sessionPendingRegister);
      strava_web.stravaWebSessionRemove(_sessionClientId);
      strava_web.stravaWebSessionRemove(_sessionRedirectUri);
      strava_web.stravaWebReplaceCleanUrl(stravaWebRedirectBase(loc));
      return true;
    } on Object {
      _webOAuthReturnHandled = false;
      rethrow;
    }
  }

  Future<void> saveTokens(
    String access,
    String refresh,
    int expiresIn, {
    String? clientId,
    String? clientSecret,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    _accessToken = access;
    _refreshToken = refresh;
    if (clientId != null && clientId.trim().isNotEmpty) {
      _clientId = clientId.trim();
      await prefs.setString(_prefsClientId, _clientId!);
    }
    if (clientSecret != null && clientSecret.trim().isNotEmpty) {
      _clientSecret = clientSecret.trim();
      await prefs.setString(_prefsClientSecret, _clientSecret!);
    }
    _expiresAt = DateTime.now().add(Duration(seconds: expiresIn));
    await prefs.setString('strava_access_token', access);
    await prefs.setString('strava_refresh_token', refresh);
    await prefs.setInt('strava_expires_at', _expiresAt!.millisecondsSinceEpoch);
  }

  /// Token correnti per `GarminService.registerStravaOnServer` (dopo OAuth / refresh).
  Future<({String access, String refresh, int expiresAtMs})?>
  getTokensForServer() async {
    await _loadInitialTokens();
    final access = _accessToken;
    final refresh = _refreshToken;
    if (access == null || refresh == null) return null;
    final exp = _expiresAt ?? DateTime.now().add(const Duration(hours: 1));
    return (
      access: access,
      refresh: refresh,
      expiresAtMs: exp.millisecondsSinceEpoch,
    );
  }

  Future<void> authenticate({
    required StravaOAuthCredentials credentials,
    required GarminService garminService,
    required String uid,
  }) async {
    await _loadInitialTokens();
    if (_accessToken != null && !_isTokenExpired()) {
      debugPrint('Token Strava già valido');
      return;
    }
    if (!credentials.isComplete) {
      throw StateError('Client ID/Secret Strava mancanti o non validi.');
    }

    final bool isMobile =
        !kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.iOS ||
            defaultTargetPlatform == TargetPlatform.android);

    final bool isDesktop =
        !kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.windows ||
            defaultTargetPlatform == TargetPlatform.macOS ||
            defaultTargetPlatform == TargetPlatform.linux);

    // Per mobile: Strava richiede oauth/mobile/authorize (non oauth/authorize)
    // altrimenti può dare "redirect uri invalid" anche con Callback Domain corretto
    final String authUrlBase = isMobile
        ? 'https://www.strava.com/oauth/mobile/authorize?'
        : 'https://www.strava.com/oauth/authorize?';
    final Map<String, String> params = {
      'client_id': credentials.clientId,
      'response_type': 'code',
      'scope': 'read,activity:read_all,profile:read_all',
      'approval_prompt': 'auto',
    };

    if (isMobile) {
      params['redirect_uri'] = redirectUri;

      // iOS Safari: usa endpoint web (oauth/authorize) invece di mobile - evita "invalid redirect_uri"
      final String urlBase = defaultTargetPlatform == TargetPlatform.iOS
          ? 'https://www.strava.com/oauth/authorize?'
          : authUrlBase;
      final authUrl = Uri.parse(
        urlBase,
      ).replace(queryParameters: params).toString();
      debugPrint('Flutter su mobile → $urlBase, redirect: $redirectUri');

      String? code;

      // iOS: SFSafariViewController (inAppBrowserView) NON gestisce redirect a custom scheme:
      // Strava fa redirect a myhealthsync://... ma l'app non riceve il callback.
      // Usiamo Safari esterno (externalApplication) così il redirect apre l'app.
      if (defaultTargetPlatform == TargetPlatform.iOS) {
        debugPrint(
          'iOS: uso Safari esterno per OAuth (redirect custom scheme)',
        );
        final waitFuture = StravaOAuthCallback.instance.waitForCallback();
        final launched = await launchUrl(
          Uri.parse(authUrl),
          mode: LaunchMode.externalApplication,
        );
        if (!launched) {
          throw Exception(
            'Impossibile aprire Strava. Verifica la connessione.',
          );
        }
        code = await waitFuture;
      } else {
        final result = await FlutterWebAuth2.authenticate(
          url: authUrl,
          callbackUrlScheme: callbackScheme,
        );
        final uri = Uri.parse(result);
        code = uri.queryParameters['code'];
      }

      if (code == null) {
        throw Exception('Nessun code ricevuto da Strava (mobile)');
      }
      await _exchangeCodeForTokenOnServer(
        code,
        garminService: garminService,
        uid: uid,
        clientId: credentials.clientId,
        clientSecret: credentials.clientSecret,
        redirectUriUsed: redirectUri,
      );
    } else if (isDesktop) {
      final code = await desktop.runDesktopStravaOAuth(authUrlBase, params);
      await _exchangeCodeForTokenOnServer(
        code,
        garminService: garminService,
        uid: uid,
        clientId: credentials.clientId,
        clientSecret: credentials.clientSecret,
        redirectUriUsed: params['redirect_uri'],
      );
    } else if (kIsWeb) {
      // Web: GET https://www.strava.com/oauth/authorize + redirect_uri https (o localhost).
      // Lo scambio code→token avviene al reload in [completeWebOAuthIfPresent] (server: CORS).
      final loc = strava_web.stravaWebCurrentUri();
      if (loc == null) {
        throw StateError('URL corrente non disponibile (web).');
      }

      final oauthParams = _webOAuthParams(loc);
      final errParam = oauthParams['error'];
      if (errParam != null) {
        strava_web.stravaWebReplaceCleanUrl(stravaWebRedirectBase(loc));
        strava_web.stravaWebSessionRemove(_sessionOAuthState);
        strava_web.stravaWebSessionRemove(_sessionPendingRegister);
        strava_web.stravaWebSessionRemove(_sessionClientId);
        strava_web.stravaWebSessionRemove(_sessionRedirectUri);
        throw Exception(
          errParam == 'access_denied'
              ? 'Autorizzazione Strava annullata.'
              : 'Strava: $errParam',
        );
      }

      if (oauthParams['code'] != null && oauthParams['code']!.isNotEmpty) {
        throw Exception(
          'Collegamento Strava in completamento: attendi qualche secondo o aggiorna la pagina.',
        );
      }

      final state = strava_web.stravaWebNewOAuthState();
      strava_web.stravaWebSessionSet(_sessionOAuthState, state);
      strava_web.stravaWebSessionSet(_sessionPendingRegister, '1');
      strava_web.stravaWebSessionSet(_sessionClientId, credentials.clientId);

      final redirectStr = stravaOAuthWebRedirectUriString(loc);
      strava_web.stravaWebSessionSet(_sessionRedirectUri, redirectStr);
      if (!redirectStr.startsWith('https://') &&
          !redirectStr.startsWith('http://localhost') &&
          !redirectStr.startsWith('http://127.0.0.1')) {
        debugPrint(
          'Strava web: usa https o http://localhost come URL dell’app; '
          'Authorization Callback Domain su strava.com/settings/api deve coincidere (es. localhost).',
        );
      }

      final paramsWeb = <String, String>{
        'client_id': credentials.clientId,
        'response_type': 'code',
        'scope': 'read,activity:read_all,profile:read_all',
        'approval_prompt': 'auto',
        'redirect_uri': redirectStr,
        'state': state,
      };
      final authUrl = Uri.parse(
        'https://www.strava.com/oauth/authorize',
      ).replace(queryParameters: paramsWeb).toString();

      debugPrint('Strava web → oauth/authorize, redirect_uri=$redirectStr');
      strava_web.stravaWebAssignLocation(authUrl);
      throw const StravaWebOAuthRedirectPending();
    } else {
      throw UnsupportedError('Piattaforma non supportata per Strava OAuth');
    }
  }

  Future<void> _exchangeCodeForTokenOnServer(
    String code, {
    required GarminService garminService,
    required String uid,
    required String clientId,
    required String clientSecret,
    String? redirectUriUsed,
  }) async {
    final reg = await garminService.exchangeStravaOAuthCodeOnServer(
      uid: uid,
      code: code,
      redirectUri: redirectUriUsed ?? redirectUri,
      clientId: clientId,
    );

    if (reg['success'] != true) {
      throw Exception(
        reg['message']?.toString() ??
            'Exchange OAuth Strava sul server fallito.',
      );
    }

    final access = reg['access_token'] as String?;
    final refresh = reg['refresh_token'] as String?;
    final expiresInRaw = reg['expires_in'];
    final expiresIn = expiresInRaw is int
        ? expiresInRaw
        : int.tryParse('$expiresInRaw') ?? 21600;
    if (access == null || refresh == null) {
      throw StateError('Risposta server Strava incompleta (token mancanti).');
    }
    await saveTokens(
      access,
      refresh,
      expiresIn,
      clientId: clientId,
      clientSecret: clientSecret,
    );
  }

  bool _isTokenExpired() =>
      _expiresAt == null ||
      DateTime.now().isAfter(_expiresAt!.subtract(const Duration(minutes: 5)));

  Future<void> _performTokenRefresh() async {
    final clientId = _clientId;
    final clientSecret = _clientSecret;
    if (clientId == null ||
        clientSecret == null ||
        clientId.isEmpty ||
        clientSecret.isEmpty) {
      throw StateError(
        'Client ID/Secret Strava mancanti: ricollega Strava dalle Impostazioni.',
      );
    }
    final response = await http.post(
      Uri.parse('https://www.strava.com/oauth/token'),
      body: {
        'client_id': clientId,
        'client_secret': clientSecret,
        'refresh_token': _refreshToken,
        'grant_type': 'refresh_token',
      },
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      await saveTokens(
        data['access_token'],
        data['refresh_token'] ?? _refreshToken!,
        data['expires_in'],
      );
    } else {
      throw Exception('Refresh Strava fallito');
    }
  }

  /// Dettaglio completo (calories, laps) — chiama solo al tap per rispettare rate limit 100/15min
  Future<StravaActivity> getDetailedActivity(int activityId) async {
    await _loadInitialTokens();
    if (_isTokenExpired()) await _performTokenRefresh();

    final response = await http
        .get(
          Uri.parse('https://www.strava.com/api/v3/activities/$activityId'),
          headers: {'Authorization': 'Bearer $_accessToken'},
        )
        .timeout(const Duration(seconds: 30));

    if (response.statusCode == 200) {
      return StravaActivity.fromJson(
        json.decode(response.body) as Map<String, dynamic>,
        detailed: true,
      );
    }
    throw Exception('Errore dettagli attività: ${response.body}');
  }

  /// Serie FC durante l’attività (API Streams). Richiede token utente; stessi limiti di rate del dettaglio.
  Future<List<ActivityHrPoint>?> fetchHeartRateSeries(int activityId) async {
    await _loadInitialTokens();
    if (_accessToken == null) return null;
    if (_isTokenExpired()) await _performTokenRefresh();

    final uri = Uri.parse(
      'https://www.strava.com/api/v3/activities/$activityId/streams'
      '?keys=time,heartrate&key_by_type=true',
    );
    final response = await http
        .get(uri, headers: {'Authorization': 'Bearer $_accessToken'})
        .timeout(const Duration(seconds: 45));

    if (response.statusCode == 404) return null;
    if (response.statusCode != 200) {
      throw Exception(
        'Stream FC Strava: HTTP ${response.statusCode} ${response.body}',
      );
    }
    final raw = response.body.trim();
    if (raw.isEmpty) return null;
    final decoded = json.decode(raw);
    return parseStravaHeartRateStreams(decoded);
  }
}
