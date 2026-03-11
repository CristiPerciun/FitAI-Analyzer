import 'dart:convert';

import 'package:fitai_analyzer/models/fitness_data.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

/// Servizio per fetch dati da MyFitnessPal API.
/// OAuth 2.0 Authorization Code flow.
class MfpService {
  MfpService({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  static const _authBase = 'https://api.myfitnesspal.com';
  static const _apiBase = 'https://oauth2-api.myfitnesspal.com';

  /// URL di autorizzazione OAuth 2.0.
  String getAuthorizationUrl({
    required String clientId,
    required String redirectUri,
  }) {
    final params = {
      'client_id': clientId,
      'redirect_uri': redirectUri,
      'response_type': 'code',
      'scope': 'diary',
    };
    final query = params.entries
        .map((e) => '${e.key}=${Uri.encodeComponent(e.value)}')
        .join('&');
    return '$_authBase/v2/oauth2/ui/authenticate?$query';
  }

  /// Scambia authorization code per access token.
  Future<void> exchangeCodeForToken({
    required String clientId,
    required String clientSecret,
    required String code,
    required String redirectUri,
  }) async {
    final response = await http.post(
      Uri.parse('$_apiBase/oauth2/token'),
      headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      body: {
        'grant_type': 'authorization_code',
        'code': code,
        'redirect_uri': redirectUri,
        'client_id': clientId,
        'client_secret': clientSecret,
      }.map((k, v) => MapEntry(k, v.toString())),
    );

    if (response.statusCode != 200) {
      throw Exception('MFP token exchange failed: ${response.body}');
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    await _storage.write(key: 'mfp_access_token', value: json['access_token'] as String?);
    await _storage.write(key: 'mfp_refresh_token', value: json['refresh_token'] as String?);
    await _storage.write(key: 'mfp_user_id', value: json['user_id']?.toString());
  }

  Future<String?> getStoredAccessToken() async {
    return _storage.read(key: 'mfp_access_token');
  }

  Future<String?> getStoredUserId() async {
    return _storage.read(key: 'mfp_user_id');
  }

  /// Fetch diary per data (calorie, pasti, esercizi).
  /// GET /v2/diary?date=YYYY-MM-DD
  /// [clientId] per header Api-Key (richiesto da MFP API).
  Future<List<FitnessData>> fetchData(
    String accessToken, {
    String? clientId,
  }) async {
    try {
      final userId = await getStoredUserId();
      if (userId == null) throw StateError('MFP user_id mancante');

      final date = DateTime.now();
      final dateStr = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

      final headers = <String, String>{
        'Authorization': 'Bearer $accessToken',
        'Accept': 'application/json',
      };
      if (clientId != null) headers['Api-Key'] = clientId;

      final response = await http.get(
        Uri.parse('$_apiBase/v2/diary?date=$dateStr&user_id=$userId'),
        headers: headers,
      );

      if (response.statusCode == 401) {
        throw Exception('Token scaduto o non valido');
      }
      if (response.statusCode != 200) {
        throw Exception('MFP API error: ${response.statusCode}');
      }

      final json = jsonDecode(response.body);
      return _parseDiary(json, dateStr);
    } catch (e) {
      rethrow;
    }
  }

  List<FitnessData> _parseDiary(dynamic json, String dateStr) {
    final list = <FitnessData>[];
    final date = DateTime.tryParse(dateStr) ?? DateTime.now();

    Iterable<dynamic> items = const [];
    if (json is Map && json['items'] != null) {
      items = json['items'] as Iterable;
    } else if (json is List) {
      items = json;
    }

    double totalCalories = 0;
    double totalSteps = 0;
    double totalExerciseCal = 0;

    for (final item in items) {
      if (item is! Map<String, dynamic>) continue;
      final type = item['type'] as String?;

      if (type == 'diary_meal') {
        final nc = item['nutritional_contents'] as Map<String, dynamic>?;
        if (nc != null) {
          final energy = nc['energy'];
          if (energy is Map && energy['unit'] == 'calories') {
            totalCalories += (energy['value'] as num?)?.toDouble() ?? 0;
          }
        }
      } else if (type == 'exercise' || type == 'exercise_entry') {
        final energy = item['energy'];
        if (energy is Map && energy['unit'] == 'calories') {
          totalExerciseCal += (energy['value'] as num?)?.toDouble() ?? 0;
        }
      } else if (type == 'steps_aggregate' || type == 'steps') {
        totalSteps += (item['steps'] as num?)?.toDouble() ?? 0;
      }
    }

    if (totalCalories > 0 || totalSteps > 0 || totalExerciseCal > 0) {
      list.add(FitnessData(
        id: 'mfp_$dateStr',
        source: 'mfp',
        date: date,
        calories: totalCalories > 0 ? totalCalories : null,
        steps: totalSteps > 0 ? totalSteps : null,
        activeMinutes: totalExerciseCal > 0 ? totalExerciseCal / 5 : null,
        raw: {
          'totalCalories': totalCalories,
          'totalSteps': totalSteps,
          'totalExerciseCal': totalExerciseCal,
        },
      ));
    }

    return list;
  }

  Future<void> clearTokens() async {
    await _storage.delete(key: 'mfp_access_token');
    await _storage.delete(key: 'mfp_refresh_token');
    await _storage.delete(key: 'mfp_user_id');
  }
}
