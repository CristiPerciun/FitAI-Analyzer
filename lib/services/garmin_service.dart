import 'dart:convert';

import 'package:fitai_analyzer/models/fitness_data.dart';
import 'package:fitai_analyzer/utils/pkce.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

/// Servizio per fetch dati da Garmin Connect API.
/// OAuth 2.0 PKCE flow. Credenziali in Secure Storage.
class GarminService {
  GarminService({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  static const _authBase = 'https://connect.garmin.com';
  static const _apiBase = 'https://connectapi.garmin.com';

  /// Genera URL di autorizzazione OAuth 2.0 PKCE.
  Future<String> getAuthorizationUrl({
    required String clientId,
    required String redirectUri,
  }) async {
    final verifier = generateCodeVerifier();
    final challenge = generateCodeChallenge(verifier);
    await _storage.write(
      key: 'garmin_code_verifier',
      value: verifier,
    );
    final params = {
      'client_id': clientId,
      'redirect_uri': redirectUri,
      'response_type': 'code',
      'scope': 'health:read',
      'code_challenge': challenge,
      'code_challenge_method': 'S256',
    };
    final query = params.entries.map((e) => '${e.key}=${Uri.encodeComponent(e.value)}').join('&');
    return '$_authBase/oauthConfirm?$query';
  }

  /// Scambia authorization code per access token.
  Future<void> exchangeCodeForToken({
    required String clientId,
    required String clientSecret,
    required String code,
    required String redirectUri,
  }) async {
    final verifier = await _storage.read(key: 'garmin_code_verifier');
    if (verifier == null) throw StateError('Code verifier mancante');

    final response = await http.post(
      Uri.parse('$_apiBase/oauth/token'),
      headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      body: {
        'client_id': clientId,
        'client_secret': clientSecret,
        'code': code,
        'code_verifier': verifier,
        'grant_type': 'authorization_code',
        'redirect_uri': redirectUri,
      }.map((k, v) => MapEntry(k, v.toString())),
    );

    if (response.statusCode != 200) {
      throw Exception('Token exchange failed: ${response.body}');
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    await _storage.write(key: 'garmin_access_token', value: json['access_token'] as String?);
    await _storage.write(key: 'garmin_refresh_token', value: json['refresh_token'] as String?);
  }

  /// Recupera access token da storage (o da parametro).
  Future<String?> getStoredAccessToken() async {
    return _storage.read(key: 'garmin_access_token');
  }

  /// Fetch dati wellness/attività da Garmin Connect API.
  /// Endpoint: wellness-api per daily summary (steps, calories, ecc.)
  Future<List<FitnessData>> fetchData(String accessToken) async {
    try {
      final response = await http.get(
        Uri.parse('$_apiBase/wellness-api/rest/dailies'),
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 401) {
        throw Exception('Token scaduto o non valido');
      }
      if (response.statusCode != 200) {
        throw Exception('Garmin API error: ${response.statusCode}');
      }

      final json = jsonDecode(response.body);
      return _parseDailies(json);
    } catch (e) {
      rethrow;
    }
  }

  List<FitnessData> _parseDailies(dynamic json) {
    final list = <FitnessData>[];
    Iterable<dynamic> items = const [];
    if (json is List) {
      items = json;
    } else if (json is Map && json['dailies'] != null) {
      items = json['dailies'] as Iterable;
    } else if (json is Map && json['calendarDate'] != null) {
      items = [json];
    }

    for (final item in items) {
      if (item is! Map<String, dynamic>) continue;
      final dateStr = item['calendarDate'] as String? ?? item['date'] as String?;
      final date = dateStr != null ? DateTime.tryParse(dateStr) : null;
      if (date == null) continue;

      final steps = (item['totalSteps'] ?? item['steps'] ?? 0) as num?;
      final calories = (item['activeKilocalories'] ?? item['calories'] ?? item['activeCalories'] ?? 0) as num?;
      final distance = (item['totalDistance'] ?? item['distance'] ?? 0) as num?;
      final activeMins = (item['activeTimeInSeconds'] ?? item['activeMinutes'] ?? 0) as num?;

      list.add(FitnessData(
        id: item['id']?.toString() ?? '',
        source: 'garmin',
        date: date,
        steps: steps?.toDouble(),
        calories: calories?.toDouble(),
        distanceKm: distance != null ? (distance.toDouble() / 1000) : null,
        activeMinutes: activeMins != null ? (activeMins.toDouble() / 60) : null,
        raw: item,
      ));
    }
    return list;
  }

  Future<void> clearTokens() async {
    await _storage.delete(key: 'garmin_access_token');
    await _storage.delete(key: 'garmin_refresh_token');
    await _storage.delete(key: 'garmin_code_verifier');
  }
}
