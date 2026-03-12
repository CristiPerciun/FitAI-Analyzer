import 'package:flutter_riverpod/flutter_riverpod.dart';

enum StravaSyncPhase { idle, connecting, completed, error }

class StravaSyncStatus {
  final StravaSyncPhase phase;
  final String? message;
  final String? error;

  StravaSyncStatus({
    this.phase = StravaSyncPhase.idle,
    this.message,
    this.error,
  });
}

class StravaSyncStatusNotifier extends Notifier<StravaSyncStatus> {
  @override
  StravaSyncStatus build() => StravaSyncStatus();

  void setPhase(StravaSyncPhase phase, {String? message}) {
    state = StravaSyncStatus(phase: phase, message: message);
  }

  void setError(String error) {
    state = StravaSyncStatus(phase: StravaSyncPhase.error, error: error);
  }

  void reset() {
    state = StravaSyncStatus();
  }
}

final stravaSyncStatusProvider =
    NotifierProvider<StravaSyncStatusNotifier, StravaSyncStatus>(
  StravaSyncStatusNotifier.new,
);
