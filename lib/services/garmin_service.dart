import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../models/fitness_data.dart';
import '../utils/platform_firestore_fix.dart';
import '../models/garmin_activity_model.dart';
import '../models/garmin_daily_model.dart';

final garminServiceProvider = Provider<GarminService>((ref) => GarminService());

/// URL del garmin-sync-server su fly.io. Cambia se usi un deploy diverso.
const String garminServerUrl = 'https://garmin-sync-server.fly.dev';

/// Servizio per lettura dati Garmin da Firestore e connessione via server.
/// I dati sono scritti dal garmin-sync-server Python (deploy su fly.io).
/// Collezioni: users/{uid}/garmin_activities, users/{uid}/garmin_daily
class GarminService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Stream real-time attività Garmin (ultime 30).
  /// Su Windows usa polling per evitare errori "non-platform thread".
  Stream<List<GarminActivityModel>> garminActivitiesStream(String uid) {
    final query = _firestore
        .collection('users')
        .doc(uid)
        .collection('garmin_activities')
        .orderBy('startTime', descending: true)
        .limit(30);
    return querySnapshotStream(query).map((snap) => snap.docs
        .map((d) => GarminActivityModel.fromFirestore(d.data(), d.id))
        .toList());
  }

  /// Dati giornalieri Garmin (stats, heartRate, sleep).
  Future<GarminDailyModel?> getDailyGarminData(String uid, String date) async {
    final doc = await _firestore
        .collection('users')
        .doc(uid)
        .collection('garmin_daily')
        .doc(date)
        .get();

    if (!doc.exists || doc.data() == null) return null;
    return GarminDailyModel.fromFirestore(doc.data()!, doc.id);
  }

  /// Timeout per connect: 60s per cold start fly.io (auto_stop_machines).
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
      final response = await http.post(
        Uri.parse('$garminServerUrl/garmin/connect'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'uid': uid,
          'email': email.trim(),
          'password': password,
        }),
      ).timeout(_connectTimeout);

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode == 200 && data['success'] == true) {
        return {'success': true, 'message': data['message']?.toString() ?? 'Garmin collegato!'};
      }
      return {
        'success': false,
        'message': data['detail']?.toString() ?? 'Credenziali non valide o errore server',
      };
    } on TimeoutException {
      return {
        'success': false,
        'message': 'Server in avvio (fly.io cold start). Attendi 1 min e riprova.',
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
      final response = await http.post(
        Uri.parse('$garminServerUrl/garmin/disconnect'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'uid': uid}),
      ).timeout(const Duration(seconds: 30));

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode == 200 && data['success'] == true) {
        return {'success': true, 'message': data['message']?.toString() ?? 'Garmin scollegato.'};
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
  Future<Map<String, dynamic>> syncNow({
    required String uid,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse('$garminServerUrl/garmin/sync-vitals'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'uid': uid}),
          )
          .timeout(_syncTimeout);

      final body = response.body.trim();
      final data = body.isEmpty
          ? <String, dynamic>{}
          : jsonDecode(body) as Map<String, dynamic>;

      if (response.statusCode == 200 && data['success'] == true) {
        return {
          'success': true,
          'message':
              data['message']?.toString() ?? 'Sync Garmin completata.',
        };
      }

      return {
        'success': false,
        'message': data['detail']?.toString() ??
            data['message']?.toString() ??
            'Sync Garmin non riuscita.',
      };
    } on TimeoutException {
      return {
        'success': false,
        'message': 'La sync Garmin sta impiegando troppo tempo. Riprova tra poco.',
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
  }

  /// Converte GarminActivityModel in FitnessData per riuso con CompactActivityCard.
  static FitnessData toFitnessData(GarminActivityModel g) {
    final dt = g.startDateTime ?? DateTime.now();
    return FitnessData(
      id: 'garmin_${g.activityId}',
      source: 'garmin',
      date: dt,
      calories: g.calories,
      distanceKm: g.distanceKm > 0 ? g.distanceKm : null,
      activeMinutes: g.activeMinutes,
      activityType: g.activityType,
      activityName: g.rawData?['activityName']?.toString(),
      avgHeartrate: g.averageHR,
      raw: g.rawData,
      elapsedMinutes: g.activeMinutes,
    );
  }
}
