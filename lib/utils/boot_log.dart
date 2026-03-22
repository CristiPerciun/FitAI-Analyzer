import 'package:flutter/foundation.dart';

/// Log sequenza avvio app. Filtra la console con `[FitAI:Boot]`.
/// Disattivato in release per non sporcare log in produzione.
void bootLog(String message) {
  if (kReleaseMode) return;
  debugPrint('[FitAI:Boot] +${_BootClock.ms}ms $message');
}

final class _BootClock {
  static final Stopwatch _sw = Stopwatch()..start();
  static int get ms => _sw.elapsedMilliseconds;
}
