import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../models/fitness_data.dart';
import '../utils/platform_firestore_fix.dart';

final garminServiceProvider = Provider<GarminService>((ref) => GarminService());

/// URL del garmin-sync-server. Aggiorna con il tuo URL Render (es. https://garmin-sync-server.onrender.com).
const String garminServerUrl = 'https://garmin-sync-server.onrender.com';

/// Servizio per lettura dati Garmin da Firestore e connessione via server.
/// I dati sono scritti dal garmin-sync-server Python (deploy su Render).
/// Collezioni: users/{uid}/activities, users/{uid}/daily_health
class GarminService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

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

  /// Timeout per connect: 60s per cold start (Render/Fly auto-stop).
  static const Duration _connectTimeout = Duration(seconds: 60);
  static const Duration _syncTimeout = Duration(seconds: 90);

  Future<bool> isConnected(String uid) async {
    final doc = await _firestore.collection('users').doc(uid).get();
    return doc.data()?['garmin_linked'] == true;
  }

  /// Invia credenziali Garmin al server per collegare l'account.
  /// Il server valida su Garmin Connect e salva i token.
  Future<Map<String, dynamic>> connect({
    required String uid,
    required String email,
    required String password,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse('$garminServerUrl/garmin/connect'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'uid': uid,
              'email': email.trim(),
              'password': password,
            }),
          )
          .timeout(_connectTimeout);

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode == 200 && data['success'] == true) {
        return {
          'success': true,
          'message': data['message']?.toString() ?? 'Garmin collegato!',
        };
      }
      return {
        'success': false,
        'message':
            data['detail']?.toString() ??
            'Credenziali non valide o errore server',
      };
    } on TimeoutException {
      return {
        'success': false,
        'message':
            'Server in avvio. Attendi 1 min e riprova.',
      };
    } on Exception catch (e) {
      final msg = e.toString().toLowerCase();
      return {
        'success': false,
        'message': msg.contains('socket') || msg.contains('connection')
            ? 'Server non raggiungibile. Verifica la connessione.'
            : 'Errore di rete. Riprova più tardi.',
      };
    }
  }

  /// Scollega l'account Garmin: elimina token sul server e aggiorna Firestore.
  Future<Map<String, dynamic>> disconnect({required String uid}) async {
    try {
      final response = await http
          .post(
            Uri.parse('$garminServerUrl/garmin/disconnect'),
            headers: {'Content-Type': 'application/json'},
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
      final response = await http
          .post(
            Uri.parse('$garminServerUrl/garmin/sync-vitals'),
            headers: {'Content-Type': 'application/json'},
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
