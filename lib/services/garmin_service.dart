import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../models/fitness_data.dart';
import '../utils/platform_firestore_fix.dart';

final garminServiceProvider = Provider<GarminService>((ref) => GarminService());

/// URL del garmin-sync-server (`.env` → `GARMIN_SERVER_URL`).
/// Esempio LAN / Raspberry Pi: `http://192.168.x.x:8080` — vedi `RPI_DEPLOY.md` nel repo garmin-sync-server.
/// Fallback `127.0.0.1` solo per sviluppo locale; su telefono imposta sempre l’IP del Pi o tunnel.
String get garminServerUrl {
  if (!dotenv.isInitialized) {
    return 'http://127.0.0.1:8080';
  }
  final u = dotenv.env['GARMIN_SERVER_URL']?.trim();
  return (u != null && u.isNotEmpty) ? u : 'http://127.0.0.1:8080';
}

/// Servizio per lettura dati Garmin da Firestore e connessione via server.
/// I dati sono scritti dal garmin-sync-server Python (es. su Raspberry Pi).
/// Collezioni: users/{uid}/activities, users/{uid}/daily_health
class GarminService {
  GarminService({
    http.Client? httpClient,
    String? serverUrlOverride,
  })  : _http = httpClient ?? http.Client(),
        _serverUrlOverride = serverUrlOverride;

  final http.Client _http;
  final String? _serverUrlOverride;

  /// Lazy: evita `Firebase.initializeApp()` quando si usano solo connect/sync/disconnect (es. test).
  FirebaseFirestore get _firestore => FirebaseFirestore.instance;

  String get _baseUrl {
    final o = _serverUrlOverride?.trim();
    return (o != null && o.isNotEmpty) ? o : garminServerUrl;
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

  /// Timeout per connect: 60s (rete lenta o server che si sveglia da sospensione).
  static const Duration _connectTimeout = Duration(seconds: 60);
  static const Duration _syncTimeout = Duration(seconds: 90);

  Future<bool> isConnected(String uid) async {
    final doc = await _firestore.collection('users').doc(uid).get();
    return doc.data()?['garmin_linked'] == true;
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

  /// Invia credenziali Garmin al server per collegare l'account.
  /// Il server valida su Garmin Connect e salva i tokens.
  Future<Map<String, dynamic>> connect({
    required String uid,
    required String email,
    required String password,
  }) async {
    final uri = Uri.parse('$_baseUrl/garmin/connect');
    try {
      final response = await _http
          .post(
            uri,
            headers: _jsonHeaders,
            body: jsonEncode({
              'uid': uid,
              'email': email.trim(),
              'password': password,
            }),
          )
          .timeout(_connectTimeout);

      final data = _tryDecodeJsonObject(response.body);
      if (response.statusCode == 200 &&
          data != null &&
          data['success'] == true) {
        return {
          'success': true,
          'message': data['message']?.toString() ?? 'Garmin collegato!',
        };
      }

      if (response.statusCode == 200 &&
          data != null &&
          data['success'] == false) {
        final msg = _serverDetailOrMessage(data);
        return {
          'success': false,
          'message': msg.isNotEmpty
              ? msg
              : 'Login Garmin non completato (sync iniziale fallita o altro).',
        };
      }

      final err = _serverDetailOrMessage(data);
      if (err.isNotEmpty) {
        return {'success': false, 'message': err};
      }

      final snippet = response.body.length > 160
          ? '${response.body.substring(0, 160)}…'
          : response.body;
      return {
        'success': false,
        'message':
            'Risposta server HTTP ${response.statusCode} da $_baseUrl. '
            '${snippet.isEmpty ? '(corpo vuoto)' : snippet}',
      };
    } on TimeoutException {
      return {
        'success': false,
        'message':
            'Timeout: il server non ha risposto in tempo ($_baseUrl). '
            'Controlla che il Pi sia acceso, stessa rete/Wi‑Fi e GARMIN_SERVER_URL in .env.',
      };
    } on Object catch (e) {
      final s = e.toString().toLowerCase();
      if (s.contains('socket') ||
          s.contains('connection') ||
          s.contains('failed host lookup') ||
          s.contains('network')) {
        return {
          'success': false,
          'message':
              'Server non raggiungibile ($_baseUrl). Stesso Wi‑Fi del telefono? '
              'Verifica GARMIN_SERVER_URL in .env (es. http://IP_PI:8080).',
        };
      }
      return {
        'success': false,
        'message': 'Errore di rete: $e',
      };
    }
  }

  /// Scollega l'account Garmin: elimina token sul server e aggiorna Firestore.
  Future<Map<String, dynamic>> disconnect({required String uid}) async {
    try {
      final response = await _http
          .post(
            Uri.parse('$_baseUrl/garmin/disconnect'),
            headers: _jsonHeaders,
            body: jsonEncode({'uid': uid}),
          )
          .timeout(const Duration(seconds: 30));

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
    } on TimeoutException {
      return {'success': false, 'message': 'Server non risponde. Riprova.'};
    } on Exception catch (e) {
      final msg = e.toString().toLowerCase();
      return {
        'success': false,
        'message': msg.contains('socket') || msg.contains('connection')
            ? 'Server non raggiungibile.'
            : 'Errore di rete.',
      };
    }
  }

  /// Richiede una sync immediata al mini-server usando i token Garmin gia' salvati.
  /// Usa /garmin/sync-vitals (oggi + ieri) per pull-to-refresh leggero.
  /// Ritenta una volta in caso di timeout/connessione (cold start).
  Future<Map<String, dynamic>> syncNow({required String uid}) async {
    Future<Map<String, dynamic>> doRequest() async {
      final response = await _http
          .post(
            Uri.parse('$_baseUrl/garmin/sync-vitals'),
            headers: _jsonHeaders,
            body: jsonEncode({'uid': uid}),
          )
          .timeout(_syncTimeout);

      // 5xx = server in avvio (cold start), ritenta
      if (response.statusCode >= 500 && response.statusCode < 600) {
        throw Exception('Server unavailable');
      }

      final body = response.body.trim();
      final data = body.isEmpty
          ? <String, dynamic>{}
          : jsonDecode(body) as Map<String, dynamic>;

      if (response.statusCode == 200 && data['success'] == true) {
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
            'Sync Garmin non riuscita.',
      };
    }

    try {
      return await doRequest();
    } on TimeoutException {
      // Ritenta: cold start può richiedere più tempo al primo wake
      await Future<void>.delayed(const Duration(seconds: 3));
      try {
        return await doRequest();
      } on TimeoutException {
        return {
          'success': false,
          'message':
              'La sync Garmin sta impiegando troppo tempo. Riprova tra poco.',
        };
      } on Exception catch (e) {
        final msg = e.toString().toLowerCase();
        return {
          'success': false,
          'message': msg.contains('socket') || msg.contains('connection')
              ? 'Mini-server Garmin non raggiungibile.'
              : 'Errore di rete durante la sync Garmin.',
        };
      }
    } on Exception catch (e) {
      final msg = e.toString().toLowerCase();
      final isRetryable = msg.contains('socket') ||
          msg.contains('connection') ||
          msg.contains('timeout') ||
          msg.contains('unavailable');
      if (isRetryable) {
        await Future<void>.delayed(const Duration(seconds: 3));
        try {
          return await doRequest();
        } on Exception catch (e2) {
          final m2 = e2.toString().toLowerCase();
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
