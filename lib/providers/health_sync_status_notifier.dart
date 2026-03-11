import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Fasi del sync Health per debug (senza debug diretto su iPhone).
enum HealthSyncPhase {
  idle,
  configuring,
  requestingPermissions,
  permissionsResult,
  fetchingData,
  dataReceived,
  savingToFirestore,
  complete,
  error,
}

/// Stato dettagliato del sync Health per visualizzazione debug.
class HealthSyncStatus {
  final HealthSyncPhase phase;
  final String? message;
  final Object? rawResponse;
  final String? error;

  const HealthSyncStatus({
    this.phase = HealthSyncPhase.idle,
    this.message,
    this.rawResponse,
    this.error,
  });

  HealthSyncStatus copyWith({
    HealthSyncPhase? phase,
    String? message,
    Object? rawResponse,
    Object? error,
  }) {
    return HealthSyncStatus(
      phase: phase ?? this.phase,
      message: message ?? this.message,
      rawResponse: rawResponse ?? this.rawResponse,
      error: identical(error, _omit) ? this.error : error as String?,
    );
  }

  bool get isActive =>
      phase != HealthSyncPhase.idle &&
      phase != HealthSyncPhase.complete &&
      phase != HealthSyncPhase.error;
}

const _omit = Object();

class HealthSyncStatusNotifier extends Notifier<HealthSyncStatus> {
  @override
  HealthSyncStatus build() => const HealthSyncStatus();

  void setPhase(HealthSyncPhase phase, {String? message, Object? rawResponse}) {
    state = state.copyWith(
      phase: phase,
      message: message,
      rawResponse: rawResponse,
      error: null,
    );
  }

  void setError(String error) {
    state = state.copyWith(
      phase: HealthSyncPhase.error,
      error: error,
    );
  }

  void reset() {
    state = const HealthSyncStatus();
  }
}

final healthSyncStatusProvider =
    NotifierProvider<HealthSyncStatusNotifier, HealthSyncStatus>(
  HealthSyncStatusNotifier.new,
);
