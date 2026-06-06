import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fitai_analyzer/models/user_profile.dart';
import 'package:fitai_analyzer/providers/auth_notifier.dart';
import 'package:fitai_analyzer/services/aggregation_service.dart';
import 'package:fitai_analyzer/services/nutrition_calculator_service.dart';
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
      final toSave = profile.nutritionGoal != null
          ? NutritionCalculatorService.profileWithComputedCalorieTarget(profile)
          : profile;

      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('profile')
          .doc('profile')
          .set(toSave.toJson(), SetOptions(merge: true));

      if (toSave.nutritionGoal != null) {
        await NutritionCalculatorService.syncNutritionFieldsToBaseline(
          firestore: FirebaseFirestore.instance,
          uid: uid,
          profile: toSave,
        );
      }

      state = state.copyWith(
        profile: toSave,
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

  /// Aggiorna solo l’obiettivo nutrizione, ricalcola kcal target, baseline e aggregati.
  Future<void> updateNutritionGoal(NutritionGoal goal) async {
    final uid = _uid;
    if (uid == null) {
      state = state.copyWith(error: 'Utente non autenticato');
      throw StateError('Utente non autenticato');
    }

    final current = state.profile;
    if (current == null) {
      state = state.copyWith(error: 'Profilo non caricato');
      throw StateError('Profilo non caricato');
    }

    state = state.copyWith(isLoading: true, error: null);
    // `copyWith` preserva tutti gli altri campi (inclusi quelli specifici per
    // obiettivo): mai ricostruire il profilo a mano qui.
    final toSave = NutritionCalculatorService.profileWithComputedCalorieTarget(
      current.copyWith(nutritionGoal: goal),
    );
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('profile')
          .doc('profile')
          .update({
            'nutrition_goal': toSave.nutritionGoal!.toJson(),
          });

      state = state.copyWith(
        profile: toSave,
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

    // Lavoro derivato NON critico: la fonte di verità è già salvata.
    await _refreshDerived(uid, toSave);
  }

  /// Salvataggio combinato (Impostazioni → Modifica onboarding): profilo principale
  /// + obiettivo nutrizione in **una sola scrittura atomica** su `profile/profile`.
  ///
  /// Evita il bug del salvataggio parziale: la fonte di verità viene scritta una
  /// volta sola; baseline/aggregati sono ricalcolati dopo, in best-effort, senza
  /// far fallire il salvataggio se uno step pesante lancia un'eccezione.
  Future<void> saveCombinedOnboarding(UserProfile profile) async {
    final uid = _uid;
    if (uid == null) {
      state = state.copyWith(error: 'Utente non autenticato');
      throw StateError('Utente non autenticato');
    }

    state = state.copyWith(isLoading: true, error: null);
    final toSave = profile.nutritionGoal != null
        ? NutritionCalculatorService.profileWithComputedCalorieTarget(profile)
        : profile;
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('profile')
          .doc('profile')
          .set(toSave.toJson(), SetOptions(merge: true));

      state = state.copyWith(
        profile: toSave,
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

    await _refreshDerived(uid, toSave);
  }

  /// Ricalcoli derivati (baseline nutrizione + rolling/baseline aggregati).
  /// **Best-effort**: un fallimento qui non deve invalidare il salvataggio del
  /// profilo (verranno ricalcolati al prossimo trigger di sync/analisi).
  Future<void> _refreshDerived(String uid, UserProfile profile) async {
    try {
      if (profile.nutritionGoal != null) {
        await NutritionCalculatorService.syncNutritionFieldsToBaseline(
          firestore: FirebaseFirestore.instance,
          uid: uid,
          profile: profile,
        );
      }
      await ref
          .read(aggregationServiceProvider)
          .updateRolling10DaysAndBaseline(uid);
    } catch (_) {
      // Ignora: profile/profile è già persistito; baseline e rolling_10days
      // sono dati derivati e verranno rigenerati.
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

/// Obiettivo nutrizione corrente (da stato notifier; null se assente o profilo non caricato).
final nutritionGoalProvider = Provider<NutritionGoal?>((ref) {
  return ref.watch(userProfileNotifierProvider).profile?.nutritionGoal;
});

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
