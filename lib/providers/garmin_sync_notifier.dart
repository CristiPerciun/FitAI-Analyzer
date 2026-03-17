import 'package:fitai_analyzer/providers/data_sync_notifier.dart';
import 'package:fitai_analyzer/providers/providers.dart';
import 'package:fitai_analyzer/services/garmin_service.dart';
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

  Future<bool> syncNow({required String uid, required String trigger}) async {
    if (state.isSyncing) return false;

    final service = ref.read(garminServiceProvider);
    final isConnected = await service.isConnected(uid);
    if (!isConnected) {
      state = state.copyWith(error: null, trigger: trigger);
      return false;
    }

    state = state.copyWith(isSyncing: true, error: null, trigger: trigger);

    final result = await service.syncNow(uid: uid);
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
      error: result['message']?.toString() ?? 'Sync Garmin non riuscita.',
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
