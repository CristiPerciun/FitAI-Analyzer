import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final stravaOAuthCredentialsServiceProvider =
    Provider<StravaOAuthCredentialsService>((ref) {
      return StravaOAuthCredentialsService(FirebaseFirestore.instance);
    });

class StravaOAuthCredentials {
  const StravaOAuthCredentials({
    required this.clientId,
    required this.clientSecret,
  });

  final String clientId;
  final String clientSecret;

  bool get isComplete =>
      StravaOAuthCredentialsService.isValidClientId(clientId) &&
      clientSecret.trim().isNotEmpty;
}

class StravaOAuthCredentialsService {
  StravaOAuthCredentialsService(this._firestore);

  final FirebaseFirestore _firestore;

  static bool isValidClientId(String value) {
    final trimmed = value.trim();
    return trimmed.isNotEmpty && RegExp(r'^\d+$').hasMatch(trimmed);
  }

  DocumentReference<Map<String, dynamic>> _doc(String uid) {
    return _firestore
        .collection('users')
        .doc(uid)
        .collection('app_sync')
        .doc('strava_oauth');
  }

  Future<StravaOAuthCredentials?> read(String uid) async {
    final snap = await _doc(uid).get();
    if (!snap.exists) return null;
    final data = snap.data() ?? {};
    final clientId = data['client_id']?.toString().trim() ?? '';
    final clientSecret = data['client_secret']?.toString().trim() ?? '';
    final credentials = StravaOAuthCredentials(
      clientId: clientId,
      clientSecret: clientSecret,
    );
    return credentials.isComplete ? credentials : null;
  }

  Future<bool> hasValidCredentials(String uid) async {
    return (await read(uid)) != null;
  }

  Future<void> save(
    String uid, {
    required String clientId,
    required String clientSecret,
  }) async {
    final cleanClientId = clientId.trim();
    final cleanSecret = clientSecret.trim();
    if (!isValidClientId(cleanClientId) || cleanSecret.isEmpty) {
      throw ArgumentError('Credenziali Strava non valide.');
    }
    await _doc(uid).set({
      'client_id': cleanClientId,
      'client_secret': cleanSecret,
      'updated_at': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}
