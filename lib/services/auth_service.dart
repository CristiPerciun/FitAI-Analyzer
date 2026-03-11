import 'package:firebase_auth/firebase_auth.dart';

/// Servizio per autenticazione Firebase.
/// Estendere con Garmin/Health OAuth quando necessario.
class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  User? get currentUser => _auth.currentUser;

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  Future<UserCredential> signInAnonymously() async {
    return _auth.signInAnonymously();
  }

  Future<void> signOut() async {
    await _auth.signOut();
  }

  /// Link account anonimo a credenziali permanenti (email/password, ecc.)
  Future<UserCredential> linkWithCredential(AuthCredential credential) async {
    final user = _auth.currentUser;
    if (user == null) throw StateError('No user to link');
    return user.linkWithCredential(credential);
  }
}
