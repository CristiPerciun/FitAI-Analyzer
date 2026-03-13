import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show debugPrint, kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_web_auth_2/flutter_web_auth_2.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import 'strava_desktop_stub.dart' if (dart.library.io) 'strava_desktop_io.dart' as desktop;
import 'strava_oauth_callback.dart';

import '../models/fitness_data.dart';

final stravaServiceProvider = Provider<StravaService>((ref) => StravaService());

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
  final Map<String, dynamic>? _raw; // per saveToFirestore (solo da API)

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

  factory StravaActivity.fromJson(Map<String, dynamic> json, {bool detailed = false}) {
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
    final raw = d.raw ?? {};
    final idStr = d.id.replaceFirst('strava_', '');
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

  Map<String, dynamic>? get rawForFirestore => _raw;
}

class StravaService {
  static const String clientId = '210889';
  static const String clientSecret = '86f8945313e8f838bb08e074be926b2c09ab7a54';
  /// Redirect URI per OAuth. In Strava (strava.com/settings/api) imposta
  /// "Authorization Callback Domain" = myhealthsync
  static const String redirectUri = 'myhealthsync://strava/callback';
  static const String callbackScheme = 'myhealthsync';

  String? _accessToken;
  String? _refreshToken;
  DateTime? _expiresAt;

  Future<void> _loadInitialTokens() async {
    final prefs = await SharedPreferences.getInstance();
    _accessToken = prefs.getString('strava_access_token');
    _refreshToken = prefs.getString('strava_refresh_token');
    final expires = prefs.getInt('strava_expires_at');
    _expiresAt = expires != null
        ? DateTime.fromMillisecondsSinceEpoch(expires)
        : null;
  }

  /// Rimuove i token salvati (es. quando manca activity:read_all).
  Future<void> _clearTokens() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('strava_access_token');
    await prefs.remove('strava_refresh_token');
    await prefs.remove('strava_expires_at');
    _accessToken = null;
    _refreshToken = null;
    _expiresAt = null;
  }

  bool _isActivityReadPermissionError(String body) =>
      body.contains('activity:read_permission') || body.contains('activity:read_all');

  Future<void> saveTokens(String access, String refresh, int expiresIn) async {
    final prefs = await SharedPreferences.getInstance();
    _accessToken = access;
    _refreshToken = refresh;
    _expiresAt = DateTime.now().add(Duration(seconds: expiresIn));
    await prefs.setString('strava_access_token', access);
    await prefs.setString('strava_refresh_token', refresh);
    await prefs.setInt('strava_expires_at', _expiresAt!.millisecondsSinceEpoch);
  }

  Future<void> authenticate() async {
    await _loadInitialTokens();
    if (_accessToken != null && !_isTokenExpired()) {
      debugPrint('Token Strava già valido');
      return;
    }

    final bool isMobile = !kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.iOS ||
            defaultTargetPlatform == TargetPlatform.android);

    final bool isDesktop = !kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.windows ||
            defaultTargetPlatform == TargetPlatform.macOS ||
            defaultTargetPlatform == TargetPlatform.linux);

    // Per mobile: Strava richiede oauth/mobile/authorize (non oauth/authorize)
    // altrimenti può dare "redirect uri invalid" anche con Callback Domain corretto
    final String authUrlBase = isMobile
        ? 'https://www.strava.com/oauth/mobile/authorize?'
        : 'https://www.strava.com/oauth/authorize?';
    final Map<String, String> params = {
      'client_id': clientId,
      'response_type': 'code',
      'scope': 'read,activity:read_all,profile:read_all',
      'approval_prompt': 'auto',
    };

    if (isMobile) {
      params['redirect_uri'] = redirectUri;

      final authUrl = Uri.parse(authUrlBase).replace(queryParameters: params).toString();
      debugPrint('Flutter su mobile → oauth/mobile/authorize, redirect: $redirectUri');

      String? code;

      // iOS: ASWebAuthenticationSession a volte non apre la pagina. Fallback con Safari.
      if (defaultTargetPlatform == TargetPlatform.iOS) {
        debugPrint('iOS: uso fallback url_launcher + deep link');
        final waitFuture = StravaOAuthCallback.instance.waitForCallback();
        final launched = await launchUrl(
          Uri.parse(authUrl),
          mode: LaunchMode.externalApplication,
        );
        if (!launched) {
          throw Exception('Impossibile aprire Strava. Verifica la connessione.');
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
      await _exchangeCodeForToken(code, redirectUriUsed: redirectUri);
    } else if (isDesktop) {
      final code = await desktop.runDesktopStravaOAuth(authUrlBase, params);
      await _exchangeCodeForToken(code, redirectUriUsed: params['redirect_uri']);
    } else {
      throw UnsupportedError(
        'Piattaforma non supportata per Strava OAuth (web?)',
      );
    }
  }

  Future<void> _exchangeCodeForToken(String code, {String? redirectUriUsed}) async {
    final body = <String, String>{
      'client_id': clientId,
      'client_secret': clientSecret,
      'code': code,
      'grant_type': 'authorization_code',
    };
    if (redirectUriUsed != null) body['redirect_uri'] = redirectUriUsed;

    final response = await http.post(
      Uri.parse('https://www.strava.com/oauth/token'),
      body: body,
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      await saveTokens(data['access_token'], data['refresh_token'], data['expires_in']);
    } else {
      throw Exception('Strava OAuth fallito: ${response.body}');
    }
  }

  bool _isTokenExpired() => _expiresAt == null || DateTime.now().isAfter(_expiresAt!.subtract(const Duration(minutes: 5)));

  Future<void> _performTokenRefresh() async {
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
      await saveTokens(data['access_token'], data['refresh_token'] ?? _refreshToken!, data['expires_in']);
    } else {
      throw Exception('Refresh Strava fallito');
    }
  }

  Future<List<StravaActivity>> getRecentActivities({int days = 30}) async {
    await _loadInitialTokens();
    if (_isTokenExpired()) await _performTokenRefresh();

    final after = (DateTime.now().subtract(Duration(days: days)).millisecondsSinceEpoch ~/ 1000);
    final response = await http
        .get(
          Uri.parse('https://www.strava.com/api/v3/athlete/activities?per_page=200&after=$after'),
          headers: {'Authorization': 'Bearer $_accessToken'},
        )
        .timeout(const Duration(seconds: 30));

    if (response.statusCode == 200) {
      final list = json.decode(response.body) as List;
      return list.map((e) => StravaActivity.fromJson(e as Map<String, dynamic>)).toList();
    }

    // Token senza scope activity:read_all → cancella e richiedi nuova autorizzazione
    if ((response.statusCode == 401 || response.statusCode == 403) &&
        _isActivityReadPermissionError(response.body)) {
      await _clearTokens();
      throw Exception(
        'Il token Strava non ha i permessi per leggere le attività. '
        'Riprova: verrà richiesta una nuova autorizzazione con i permessi corretti.',
      );
    }
    throw Exception('Errore Strava: ${response.body}');
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

  Future<void> saveToFirestore(String uid, List<StravaActivity> activities) async {
    final withRaw = activities.where((a) => a.rawForFirestore != null).toList();
    if (withRaw.isEmpty) return;

    final firestore = FirebaseFirestore.instance;
    final batch = firestore.batch();

    // Raggruppa attività per data (Livello 1 - daily_logs)
    final byDate = <String, List<StravaActivity>>{};

    for (var act in withRaw) {
      final raw = act.rawForFirestore!;
      final startDate = raw['start_date'] ?? raw['start_date_local'] ?? '';
      final date = DateTime.tryParse(startDate.toString()) ?? DateTime.now();
      final dateStr = date.toIso8601String().split('T')[0];
      byDate.putIfAbsent(dateStr, () => []).add(act);

      final distanceM = (raw['distance'] as num?)?.toDouble() ?? 0.0;
      final movingTimeSec = (raw['moving_time'] as num?)?.toInt() ?? 0;
      final elapsedSec = (raw['elapsed_time'] as num?)?.toInt() ?? movingTimeSec;
      final avgSpeed = (raw['average_speed'] as num?)?.toDouble();

      batch.set(
        firestore.collection('users').doc(uid).collection('health_data').doc('strava_${act.id}'),
        {
          'id': 'strava_${act.id}',
          'source': 'strava',
          'date': Timestamp.fromDate(date),
          'calories': (raw['calories'] as num?)?.toDouble(),
          'steps': null,
          'distanceKm': distanceM / 1000,
          'activeMinutes': movingTimeSec / 60.0,
          'raw': raw,
          'activityType': raw['sport_type'] ?? raw['type'],
          'activityName': raw['name'],
          'deviceName': raw['device_name'],
          'elevationGainM': (raw['total_elevation_gain'] as num?)?.toDouble(),
          'avgHeartrate': (raw['average_heartrate'] as num?)?.toDouble(),
          'maxHeartrate': (raw['max_heartrate'] as num?)?.toDouble(),
          'avgSpeedKmh': avgSpeed != null ? avgSpeed * 3.6 : null,
          'elapsedMinutes': elapsedSec / 60.0,
        },
      );
    }
    await batch.commit().timeout(const Duration(seconds: 30));

    // Salvataggio Livello 1 - daily_logs (merge: non sovrascrive nutrition_gemini)
    for (final entry in byDate.entries) {
      final dateStr = entry.key;
      final acts = entry.value;
      final totalBurned = acts.fold<double>(
        0,
        (s, a) => s + ((a.rawForFirestore!['calories'] as num?)?.toDouble() ?? 0),
      );
      final dailyRef = firestore
          .collection('users')
          .doc(uid)
          .collection('daily_logs')
          .doc(dateStr);

      final dailyLog = <String, dynamic>{
        'date': dateStr,
        'strava_activities': acts.map((a) => a.rawForFirestore!).toList(),
        'total_burned_kcal': totalBurned,
        'timestamp': Timestamp.fromDate(DateTime.now()),
      };

      await dailyRef.set(dailyLog, SetOptions(merge: true));
    }
  }
}
