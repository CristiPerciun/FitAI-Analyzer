import 'package:fitai_analyzer/providers/data_sync_notifier.dart';
import 'package:fitai_analyzer/providers/providers.dart';
import 'package:fitai_analyzer/services/garmin_service.dart';
import 'package:fitai_analyzer/services/strava_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class GarminSyncState {
  final bool isSyncing;
  final String? error;
  final String? trigger;
  final DateTime? lastSyncedAt;

  const GarminSyncState({
    this.isSyncing = false,
    this.error,
    this.trigger,
    this.lastSyncedAt,
  });

  GarminSyncState copyWith({
    bool? isSyncing,
    Object? error = _omit,
    Object? trigger = _omit,
    Object? lastSyncedAt = _omit,
  }) {
    return GarminSyncState(
      isSyncing: isSyncing ?? this.isSyncing,
      error: identical(error, _omit) ? this.error : error as String?,
      trigger: identical(trigger, _omit) ? this.trigger : trigger as String?,
      lastSyncedAt: identical(lastSyncedAt, _omit)
          ? this.lastSyncedAt
          : lastSyncedAt as DateTime?,
    );
  }
}

const _omit = Object();

final garminSyncNotifierProvider =
    NotifierProvider<GarminSyncNotifier, GarminSyncState>(
      GarminSyncNotifier.new,
    );

class GarminSyncNotifier extends Notifier<GarminSyncState> {
  @override
  GarminSyncState build() => const GarminSyncState();

  /// `login` → delta Garmin + Strava. Con Garmin collegato → `sync-today` leggero.
  /// Senza Garmin ma con token Strava locale → solo delta Strava sul server.
  Future<bool> syncNow({required String uid, required String trigger}) async {
    if (state.isSyncing) return false;

    final service = ref.read(garminServiceProvider);

    if (trigger == 'login') {
      state = state.copyWith(isSyncing: true, error: null, trigger: trigger);
      final last = await service.getLastSuccessfulSync(uid);
      final result = await service.deltaSync(
        uid: uid,
        lastSuccessfulSync: last,
      );
      return _finishSync(ref, result, trigger);
    }

    final garminLinked = await service.isConnected(uid);
    if (!garminLinked) {
      final stravaLocal = await ref.read(stravaServiceProvider).isConnected();
      if (!stravaLocal) {
        state = state.copyWith(error: null, trigger: trigger);
        return false;
      }
      state = state.copyWith(isSyncing: true, error: null, trigger: trigger);
      final last = await service.getLastSuccessfulSync(uid);
      final result = await service.deltaSync(
        uid: uid,
        lastSuccessfulSync: last,
        sources: const ['strava'],
      );
      return _finishSync(ref, result, trigger);
    }

    state = state.copyWith(isSyncing: true, error: null, trigger: trigger);
    final result = await service.syncToday(uid: uid);
    return _finishSync(ref, result, trigger);
  }

  bool _finishSync(Ref ref, Map<String, dynamic> result, String trigger) {
    if (result['success'] == true) {
      _invalidateGarminDependentProviders(ref);
      state = state.copyWith(
        isSyncing: false,
        error: null,
        trigger: trigger,
        lastSyncedAt: DateTime.now(),
      );
      return true;
    }

    state = state.copyWith(
      isSyncing: false,
      error: result['message']?.toString() ?? 'Sincronizzazione server non riuscita.',
      trigger: trigger,
    );
    return false;
  }

  void clearError() {
    if (state.error == null) return;
    state = state.copyWith(error: null);
  }
}

void _invalidateGarminDependentProviders(Ref ref) {
  ref.invalidate(garminConnectedProvider);
  ref.invalidate(activitiesStreamProvider);
  ref.invalidate(dailyHealthStreamProvider);
  ref.invalidate(activitiesByDateProvider);
  ref.invalidate(activityDatesProvider);
  ref.invalidate(longevityHomePackageProvider);
}
