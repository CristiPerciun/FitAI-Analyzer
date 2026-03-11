import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fitai_analyzer/models/ai_plan.dart';
import 'package:fitai_analyzer/providers/auth_notifier.dart';
import 'package:fitai_analyzer/providers/providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AiPlanNotifier extends StateNotifier<AIPlanState> {
  AiPlanNotifier(this._ref) : super(AIPlanState.initial());
  final Ref _ref;

  Future<void> generatePlan({
    required String userContext,
    required String goals,
  }) async {
    state = state.copyWith(isLoading: true, error: '');
    try {
      final content = await _ref.read(aiServiceProvider).generatePlan(
            userContext: userContext,
            goals: goals,
          );
      final uid = _ref.read(authNotifierProvider).user?.uid;
      if (uid != null) {
        final doc = FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .collection('ai_plans')
            .doc();
        final plan = AiPlan(
          id: doc.id,
          content: content,
          createdAt: DateTime.now(),
          userId: uid,
        );
        await doc.set(plan.toJson());
        state = state.copyWith(
          plans: [...state.plans, plan],
          isLoading: false,
          error: '',
        );
      } else {
        state = state.copyWith(isLoading: false, error: 'Utente non autenticato');
      }
    } catch (e) {
      state = state.copyWith(error: e.toString(), isLoading: false);
      rethrow;
    }
  }
}

final aiPlanNotifierProvider =
    StateNotifierProvider<AiPlanNotifier, AIPlanState>(
  (ref) => AiPlanNotifier(ref),
);

/// Stream provider per listen real-time ai piani AI da Firestore
final aiPlansStreamProvider = StreamProvider.autoDispose<List<AiPlan>>(
  (ref) {
    final uid = ref.watch(authNotifierProvider).user?.uid;
    if (uid == null) return Stream.value([]);
    return FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('ai_plans')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => AiPlan.fromJson({...d.data(), 'id': d.id}))
            .toList());
  },
);

class AIPlanState {
  final List<AiPlan> plans;
  final bool isLoading;
  final String? error;

  AIPlanState({this.plans = const [], this.isLoading = false, this.error});

  factory AIPlanState.initial() => AIPlanState();

  AIPlanState copyWith({
    List<AiPlan>? plans,
    bool? isLoading,
    String? error,
  }) {
    return AIPlanState(
      plans: plans ?? this.plans,
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
    );
  }
}
