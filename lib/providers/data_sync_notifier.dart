import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fitai_analyzer/models/fitness_data.dart';
import 'package:fitai_analyzer/providers/auth_notifier.dart';
import 'package:fitai_analyzer/providers/providers.dart';
import 'package:fitai_analyzer/services/garmin_service.dart';
import 'package:fitai_analyzer/services/health_service.dart';
import 'package:fitai_analyzer/utils/demo_fitness_data.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class DataSyncNotifier extends StateNotifier<DataSyncState> {
  DataSyncNotifier(this._ref) : super(DataSyncState.initial());
  final Ref _ref;

  GarminService get _garmin => _ref.read(garminServiceProvider);
  HealthService get _health => _ref.read(healthServiceProvider);

  String? get _userId => _ref.read(authNotifierProvider).user?.uid;

  Future<void> syncGarmin(String accessToken) async {
    state = state.copyWith(isSyncing: true, error: '');
    try {
      final data = await _garmin.fetchData(accessToken);
      final uid = _userId;
      if (uid != null && data.isNotEmpty) {
        final col = FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .collection('garmin_data');
        for (final d in data) {
          await col.add(d.toJson());
        }
      }
      state = state.copyWith(
        garminData: [...state.garminData, ...data],
        isSyncing: false,
        error: '',
      );
    } catch (e) {
      state = state.copyWith(error: e.toString(), isSyncing: false);
      rethrow;
    }
  }

  Future<void> syncHealth() async {
    state = state.copyWith(isSyncing: true, error: '');
    try {
      final data = await _health.fetchData();
      await _saveHealthDataToFirestore(data);
      state = state.copyWith(
        healthData: [...state.healthData, ...data],
        isSyncing: false,
        error: '',
      );
    } catch (e) {
      state = state.copyWith(error: e.toString(), isSyncing: false);
      rethrow;
    }
  }

  /// Salva dati Health su Firestore (usato da sync con fasi separate).
  Future<void> saveHealthData(List<FitnessData> data) async {
    await _saveHealthDataToFirestore(data);
    state = state.copyWith(
      healthData: [...state.healthData, ...data],
    );
  }

  Future<void> _saveHealthDataToFirestore(List<FitnessData> data) async {
    final uid = _userId;
    if (uid != null && data.isNotEmpty) {
      final col = FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('health_data');
      for (final d in data) {
        await col.add(d.toJson());
      }
    }
  }

  /// Simula sync Health con dati demo (per sviluppo su Windows senza iPhone).
  /// Stesso flusso di syncHealth ma usa getDemoHealthData().
  Future<void> syncHealthWithDemo() async {
    state = state.copyWith(isSyncing: true, error: '');
    try {
      final data = getDemoHealthData();
      final uid = _userId;
      if (uid != null && data.isNotEmpty) {
        final col = FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .collection('health_data');
        for (final d in data) {
          await col.add(d.toJson());
        }
      }
      state = state.copyWith(
        healthData: [...state.healthData, ...data],
        isSyncing: false,
        error: '',
      );
    } catch (e) {
      state = state.copyWith(error: e.toString(), isSyncing: false);
      rethrow;
    }
  }
}

final dataSyncNotifierProvider =
    StateNotifierProvider<DataSyncNotifier, DataSyncState>(
  (ref) => DataSyncNotifier(ref),
);

/// Stream provider per listen real-time ai dati Garmin da Firestore.
/// Se [kUseDemoData] è true, restituisce dati simulati (Health Connect / Garmin).
final garminDataStreamProvider = StreamProvider.autoDispose<List<FitnessData>>(
  (ref) {
    if (kUseDemoData) {
      return Stream.value(getDemoGarminData());
    }
    final uid = ref.watch(authNotifierProvider).user?.uid;
    if (uid == null) return Stream.value([]);
    return FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('garmin_data')
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => FitnessData.fromJson({...d.data(), 'id': d.id}))
            .toList());
  },
);

/// Stream provider per listen real-time ai dati Health da Firestore.
/// Se [kUseDemoData] è true, restituisce dati simulati (Apple Health).
final healthDataStreamProvider = StreamProvider.autoDispose<List<FitnessData>>(
  (ref) {
    if (kUseDemoData) {
      return Stream.value(getDemoHealthData());
    }
    final uid = ref.watch(authNotifierProvider).user?.uid;
    if (uid == null) return Stream.value([]);
    return FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('health_data')
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => FitnessData.fromJson({...d.data(), 'id': d.id}))
            .toList());
  },
);

class DataSyncState {
  final List<FitnessData> garminData;
  final List<FitnessData> healthData;
  final bool isSyncing;
  final String? error;

  DataSyncState({
    this.garminData = const [],
    this.healthData = const [],
    this.isSyncing = false,
    this.error,
  });

  factory DataSyncState.initial() => DataSyncState();

  DataSyncState copyWith({
    List<FitnessData>? garminData,
    List<FitnessData>? healthData,
    bool? isSyncing,
    String? error,
  }) {
    return DataSyncState(
      garminData: garminData ?? this.garminData,
      healthData: healthData ?? this.healthData,
      isSyncing: isSyncing ?? this.isSyncing,
      error: error ?? this.error,
    );
  }
}
