import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fitai_analyzer/models/user_profile.dart';
import 'package:fitai_analyzer/providers/auth_notifier.dart';
import 'package:fitai_analyzer/utils/platform_firestore_fix.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Stato del profilo utente con loading e gestione errori.
class UserProfileState {
  final UserProfile? profile;
  final bool isLoading;
  final String? error;

  const UserProfileState({
    this.profile,
    this.isLoading = false,
    this.error,
  });

  factory UserProfileState.initial() => const UserProfileState();

  UserProfileState copyWith({
    Object? profile = _omit,
    bool? isLoading,
    Object? error = _omit,
  }) {
    return UserProfileState(
      profile: identical(profile, _omit) ? this.profile : profile as UserProfile?,
      isLoading: isLoading ?? this.isLoading,
      error: identical(error, _omit) ? this.error : error as String?,
    );
  }
}

const _omit = Object();

class UserProfileNotifier extends Notifier<UserProfileState> {
  @override
  UserProfileState build() => UserProfileState.initial();

  String? get _uid => ref.read(authNotifierProvider).user?.uid;

  /// Carica il profilo da Firestore: users/{uid}/profile/profile
  Future<void> loadProfile() async {
    final uid = _uid;
    if (uid == null) {
      state = state.copyWith(
        profile: null,
        isLoading: false,
        error: 'Utente non autenticato',
      );
      return;
    }

    state = state.copyWith(isLoading: true, error: null);
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('profile')
          .doc('profile')
          .get();

      if (doc.exists && doc.data() != null) {
        state = state.copyWith(
          profile: UserProfile.fromJson(doc.data()!),
          isLoading: false,
          error: null,
        );
      } else {
        state = state.copyWith(
          profile: null,
          isLoading: false,
          error: null,
        );
      }
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
      rethrow;
    }
  }

  /// Salva/aggiorna il profilo in Firestore: users/{uid}/profile/profile
  Future<void> saveProfile(UserProfile profile) async {
    final uid = _uid;
    if (uid == null) {
      state = state.copyWith(error: 'Utente non autenticato');
      throw StateError('Utente non autenticato');
    }

    state = state.copyWith(isLoading: true, error: null);
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('profile')
          .doc('profile')
          .set(profile.toJson(), SetOptions(merge: true));

      state = state.copyWith(
        profile: profile,
        isLoading: false,
        error: null,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
      rethrow;
    }
  }

  /// Stream real-time del profilo da Firestore: users/{uid}/profile/profile
  /// Su Windows usa polling per evitare errori "non-platform thread".
  Stream<UserProfile?> streamProfile() {
    final uid = _uid;
    if (uid == null) return Stream.value(null);

    final docRef = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('profile')
        .doc('profile');
    return documentSnapshotStream(docRef).map((doc) {
      if (doc.exists && doc.data() != null) {
        try {
          return UserProfile.fromJson(doc.data()!);
        } catch (_) {
          return null;
        }
      }
      return null;
    });
  }
}

final userProfileNotifierProvider =
    NotifierProvider<UserProfileNotifier, UserProfileState>(
  UserProfileNotifier.new,
);

/// Stream real-time del profilo per ref.watch/ref.listen in UI.
/// Si ricrea automaticamente quando cambia l'utente autenticato.
/// Su Windows usa polling per evitare errori "non-platform thread".
final userProfileStreamProvider = StreamProvider<UserProfile?>((ref) {
  final uid = ref.watch(authNotifierProvider).user?.uid;
  if (uid == null) return Stream.value(null);
  final docRef = FirebaseFirestore.instance
      .collection('users')
      .doc(uid)
      .collection('profile')
      .doc('profile');
  return documentSnapshotStream(docRef).map((doc) {
    if (doc.exists && doc.data() != null) {
      try {
        return UserProfile.fromJson(doc.data()!);
      } catch (_) {
        return null;
      }
    }
    return null;
  });
});
