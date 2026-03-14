import 'package:firebase_auth/firebase_auth.dart';

/// Servizio per autenticazione Firebase.
/// Estendere con Health OAuth quando necessario.
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

  /// Registrazione con linking: se l'utente è anonimo, lo trasforma in utente
  /// email/password SENZA cambiare UID (i dati in /users/{uid}/ restano).
  /// Altrimenti crea un nuovo account.
  Future<UserCredential> signUpAndLink(String email, String password) async {
    final user = _auth.currentUser;
    final credential = EmailAuthProvider.credential(
      email: email,
      password: password,
    );

    if (user != null && user.isAnonymous) {
      return user.linkWithCredential(credential);
    }
    return _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  /// Login con email e password.
  Future<UserCredential> signInWithEmailAndPassword(
    String email,
    String password,
  ) async {
    return _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  /// Registrazione normale (nuovo utente, non anonimo).
  Future<UserCredential> createUserWithEmailAndPassword(
    String email,
    String password,
  ) async {
    return _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
  }
}
