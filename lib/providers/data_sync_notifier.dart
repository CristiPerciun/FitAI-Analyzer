import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fitai_analyzer/models/fitness_data.dart';
import 'package:fitai_analyzer/providers/auth_notifier.dart';
import 'package:fitai_analyzer/providers/providers.dart';
import 'package:fitai_analyzer/services/garmin_service.dart';
import 'package:fitai_analyzer/services/mfp_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class DataSyncNotifier extends StateNotifier<DataSyncState> {
  DataSyncNotifier(this._ref) : super(DataSyncState.initial());
  final Ref _ref;

  GarminService get _garmin => _ref.read(garminServiceProvider);
  MfpService get _mfp => _ref.read(mfpServiceProvider);

  String? get _userId =>
      _ref.read(authNotifierProvider).user?.uid;

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

  Future<void> syncMfp(String accessToken) async {
    state = state.copyWith(isSyncing: true, error: '');
    try {
      final data = await _mfp.fetchData(accessToken);
      final uid = _userId;
      if (uid != null && data.isNotEmpty) {
        final col = FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .collection('mfp_data');
        for (final d in data) {
          await col.add(d.toJson());
        }
      }
      state = state.copyWith(
        mfpData: [...state.mfpData, ...data],
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

/// Stream provider per listen real-time ai dati Garmin da Firestore
final garminDataStreamProvider = StreamProvider.autoDispose<List<FitnessData>>(
  (ref) {
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

/// Stream provider per listen real-time ai dati MFP da Firestore
final mfpDataStreamProvider = StreamProvider.autoDispose<List<FitnessData>>(
  (ref) {
    final uid = ref.watch(authNotifierProvider).user?.uid;
    if (uid == null) return Stream.value([]);
    return FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('mfp_data')
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => FitnessData.fromJson({...d.data(), 'id': d.id}))
            .toList());
  },
);

class DataSyncState {
  final List<FitnessData> garminData;
  final List<FitnessData> mfpData;
  final bool isSyncing;
  final String? error;

  DataSyncState({
    this.garminData = const [],
    this.mfpData = const [],
    this.isSyncing = false,
    this.error,
  });

  factory DataSyncState.initial() => DataSyncState();

  DataSyncState copyWith({
    List<FitnessData>? garminData,
    List<FitnessData>? mfpData,
    bool? isSyncing,
    String? error,
  }) {
    return DataSyncState(
      garminData: garminData ?? this.garminData,
      mfpData: mfpData ?? this.mfpData,
      isSyncing: isSyncing ?? this.isSyncing,
      error: error ?? this.error,
    );
  }
}
