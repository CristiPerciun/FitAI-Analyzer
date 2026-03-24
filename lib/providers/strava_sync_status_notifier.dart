import 'package:flutter_riverpod/flutter_riverpod.dart';

enum StravaSyncPhase { idle, connecting, completed }

class StravaSyncStatus {
  final StravaSyncPhase phase;
  final String? message;

  StravaSyncStatus({
    this.phase = StravaSyncPhase.idle,
    this.message,
  });
}

class StravaSyncStatusNotifier extends Notifier<StravaSyncStatus> {
  @override
  StravaSyncStatus build() => StravaSyncStatus();

  void setPhase(StravaSyncPhase phase, {String? message}) {
    state = StravaSyncStatus(phase: phase, message: message);
  }

  void reset() {
    state = StravaSyncStatus();
  }
}

final stravaSyncStatusProvider =
    NotifierProvider<StravaSyncStatusNotifier, StravaSyncStatus>(
  StravaSyncStatusNotifier.new,
);
