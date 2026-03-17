import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart'
    show debugPrint, kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_web_auth_2/flutter_web_auth_2.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import 'strava_desktop_stub.dart'
    if (dart.library.io) 'strava_desktop_io.dart'
    as desktop;
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
    final raw = d.stravaRaw ?? d.raw ?? {};
    final idStr =
        d.stravaActivityId ??
        (d.id.startsWith('strava_') ? d.id.replaceFirst('strava_', '') : '');
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
  /// "Authorization Callback Domain" = strava (host di myhealthsync://strava/callback)
  static const String redirectUri = 'myhealthsync://strava/callback';
  static const String callbackScheme = 'myhealthsync';
  static const Duration _activityMergeTolerance = Duration(minutes: 2);

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
    _accessToken = null;
    _refreshToken = null;
    _expiresAt = null;
  }

  Future<void> _clearTokens() => clearTokens();

  /// Verifica se Strava è collegato (token presente e valido o refreshabile).
  Future<bool> isConnected() async {
    await _loadInitialTokens();
    return _accessToken != null;
  }

  bool _isActivityReadPermissionError(String body) =>
      body.contains('activity:read_permission') ||
      body.contains('activity:read_all');

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
      'client_id': clientId,
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
      await _exchangeCodeForToken(code, redirectUriUsed: redirectUri);
    } else if (isDesktop) {
      final code = await desktop.runDesktopStravaOAuth(authUrlBase, params);
      await _exchangeCodeForToken(
        code,
        redirectUriUsed: params['redirect_uri'],
      );
    } else {
      throw UnsupportedError(
        'Piattaforma non supportata per Strava OAuth (web?)',
      );
    }
  }

  Future<void> _exchangeCodeForToken(
    String code, {
    String? redirectUriUsed,
  }) async {
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
      await saveTokens(
        data['access_token'],
        data['refresh_token'],
        data['expires_in'],
      );
    } else {
      throw Exception('Strava OAuth fallito: ${response.body}');
    }
  }

  bool _isTokenExpired() =>
      _expiresAt == null ||
      DateTime.now().isAfter(_expiresAt!.subtract(const Duration(minutes: 5)));

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
      await saveTokens(
        data['access_token'],
        data['refresh_token'] ?? _refreshToken!,
        data['expires_in'],
      );
    } else {
      throw Exception('Refresh Strava fallito');
    }
  }

  Future<List<StravaActivity>> getRecentActivities({int days = 30}) async {
    await _loadInitialTokens();
    if (_isTokenExpired()) await _performTokenRefresh();

    final after =
        (DateTime.now().subtract(Duration(days: days)).millisecondsSinceEpoch ~/
        1000);
    final response = await http
        .get(
          Uri.parse(
            'https://www.strava.com/api/v3/athlete/activities?per_page=200&after=$after',
          ),
          headers: {'Authorization': 'Bearer $_accessToken'},
        )
        .timeout(const Duration(seconds: 30));

    if (response.statusCode == 200) {
      final list = json.decode(response.body) as List;
      return list
          .map((e) => StravaActivity.fromJson(e as Map<String, dynamic>))
          .toList();
    }

    // 401/403: token scaduto, revocato o permessi insufficienti → cancella e richiedi nuova autorizzazione
    if (response.statusCode == 401 || response.statusCode == 403) {
      await _clearTokens();
      if (_isActivityReadPermissionError(response.body)) {
        throw Exception(
          'Il token Strava non ha i permessi per leggere le attività. '
          'Riprova: verrà richiesta una nuova autorizzazione con i permessi corretti.',
        );
      }
      throw Exception(
        'Sessione Strava scaduta o revocata. Tocca Strava per riconnettere.',
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

  static String _dateKey(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  static DateTime _parseStravaDate(Map<String, dynamic> raw) {
    final value = raw['start_date'] ?? raw['start_date_local'];
    final parsed = value != null ? DateTime.tryParse(value.toString()) : null;
    return parsed ?? DateTime.now();
  }

  static DateTime? _parseStoredDate(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  static String _normalizeActivityType(String? rawType) {
    final type = (rawType ?? '').toLowerCase().trim();
    if (type == 'running') return 'run';
    if (type == 'cycling' || type == 'bike') return 'ride';
    if (type == 'walking' || type == 'hiking') return 'walk';
    return type;
  }

  static bool _sameActivityType(String left, String right) {
    if (left.isEmpty || right.isEmpty) return true;
    const runLike = {'run', 'running', 'trailrun'};
    const rideLike = {'ride', 'cycling', 'bike', 'virtualride'};
    const walkLike = {'walk', 'walking', 'hike', 'hiking'};
    if (runLike.contains(left) && runLike.contains(right)) return true;
    if (rideLike.contains(left) && rideLike.contains(right)) return true;
    if (walkLike.contains(left) && walkLike.contains(right)) return true;
    return left == right;
  }

  static bool _matchesActivitySlot({
    required DateTime candidateStart,
    required DateTime incomingStart,
    required String candidateType,
    required String incomingType,
  }) {
    if (candidateStart.difference(incomingStart).abs() >
        _activityMergeTolerance) {
      return false;
    }
    return _sameActivityType(
      _normalizeActivityType(candidateType),
      _normalizeActivityType(incomingType),
    );
  }

  static bool _hasGarminData(Map<String, dynamic>? data) {
    if (data == null) return false;
    return data['hasGarmin'] == true ||
        data['source'] == 'garmin' ||
        data['source'] == 'dual' ||
        data['garmin_raw'] != null ||
        data['garminActivityId'] != null;
  }

  static Map<String, dynamic>? _findMatchingActivity(
    List<Map<String, dynamic>> existingDocs,
    DateTime startDate,
    String activityType,
  ) {
    for (final doc in existingDocs) {
      final candidateStart =
          _parseStoredDate(doc['startTime']) ?? _parseStoredDate(doc['date']);
      if (candidateStart == null) continue;
      final candidateType = doc['activityType']?.toString() ?? '';
      if (_matchesActivitySlot(
        candidateStart: candidateStart,
        incomingStart: startDate,
        candidateType: candidateType,
        incomingType: activityType,
      )) {
        return doc;
      }
    }
    return null;
  }

  static Map<String, dynamic> _buildUnifiedStravaDoc({
    required String docId,
    required Map<String, dynamic> raw,
    required DateTime startDate,
    required Map<String, dynamic>? existing,
  }) {
    final distanceM = (raw['distance'] as num?)?.toDouble() ?? 0.0;
    final movingTimeSec = (raw['moving_time'] as num?)?.toInt() ?? 0;
    final elapsedSec = (raw['elapsed_time'] as num?)?.toInt() ?? movingTimeSec;
    final avgSpeed = (raw['average_speed'] as num?)?.toDouble();
    final hasGarmin = _hasGarminData(existing);
    final garminRaw = existing?['garmin_raw'] as Map<String, dynamic>?;

    return {
      'id': docId,
      'source': hasGarmin ? 'dual' : 'strava',
      'date': Timestamp.fromDate(startDate),
      'startTime': Timestamp.fromDate(startDate),
      'dateKey': _dateKey(startDate),
      'calories': (raw['calories'] as num?)?.toDouble(),
      'distanceKm': distanceM / 1000,
      'activeMinutes': movingTimeSec / 60.0,
      'activityType': raw['sport_type'] ?? raw['type'],
      'activityName': raw['name'],
      'deviceName': raw['device_name'],
      'elevationGainM': (raw['total_elevation_gain'] as num?)?.toDouble(),
      'avgHeartrate': (raw['average_heartrate'] as num?)?.toDouble(),
      'maxHeartrate': (raw['max_heartrate'] as num?)?.toDouble(),
      'avgSpeedKmh': avgSpeed != null ? avgSpeed * 3.6 : null,
      'elapsedMinutes': elapsedSec / 60.0,
      'hasGarmin': hasGarmin,
      'hasStrava': true,
      'garminActivityId': existing?['garminActivityId']?.toString(),
      'stravaActivityId': raw['id']?.toString(),
      'garmin_raw': garminRaw,
      'strava_raw': raw,
      'raw': raw,
      'syncedAt': Timestamp.fromDate(DateTime.now()),
    };
  }

  Future<void> saveToFirestore(
    String uid,
    List<StravaActivity> activities,
  ) async {
    final withRaw = activities.where((a) => a.rawForFirestore != null).toList();
    if (withRaw.isEmpty) return;

    final firestore = FirebaseFirestore.instance;
    final activitiesRef = firestore
        .collection('users')
        .doc(uid)
        .collection('activities');
    final dailyLogsRef = firestore
        .collection('users')
        .doc(uid)
        .collection('daily_logs');
    final byDate = <String, List<StravaActivity>>{};

    for (final act in withRaw) {
      final raw = act.rawForFirestore!;
      final date = _parseStravaDate(raw);
      final dateStr = _dateKey(date);
      byDate.putIfAbsent(dateStr, () => []).add(act);
    }

    for (final entry in byDate.entries) {
      final dateStr = entry.key;
      final acts = entry.value;
      final existingSnapshot = await activitiesRef
          .where('dateKey', isEqualTo: dateStr)
          .get();
      final existingDocs = existingSnapshot.docs
          .map((doc) => {'id': doc.id, ...doc.data()})
          .toList();

      for (final act in acts) {
        final raw = act.rawForFirestore!;
        final startDate = _parseStravaDate(raw);
        final activityType = (raw['sport_type'] ?? raw['type'] ?? '')
            .toString();
        final existing = _findMatchingActivity(
          existingDocs,
          startDate,
          activityType,
        );
        final docId = existing?['id']?.toString() ?? 'strava_${act.id}';
        final merged = _buildUnifiedStravaDoc(
          docId: docId,
          raw: raw,
          startDate: startDate,
          existing: existing,
        );
        await activitiesRef.doc(docId).set(merged, SetOptions(merge: true));

        if (existing == null) {
          existingDocs.add(merged);
        } else {
          final index = existingDocs.indexOf(existing);
          existingDocs[index] = merged;
        }
      }

      final finalDaySnapshot = await activitiesRef
          .where('dateKey', isEqualTo: dateStr)
          .get();
      final activityIds = finalDaySnapshot.docs.map((doc) => doc.id).toList()
        ..sort();
      final totalBurned = finalDaySnapshot.docs.fold<double>(
        0,
        (runningTotal, doc) =>
            runningTotal +
            ((doc.data()['calories'] as num?)?.toDouble() ?? 0.0),
      );

      await dailyLogsRef.doc(dateStr).set({
        'date': dateStr,
        'activity_ids': activityIds,
        'health_ref': dateStr,
        'total_burned_kcal': totalBurned,
        'timestamp': Timestamp.fromDate(DateTime.now()),
      }, SetOptions(merge: true));
    }
  }
}
