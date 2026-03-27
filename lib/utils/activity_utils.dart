import 'package:flutter/material.dart';
import 'dart:ui';

/// Utility condivise per attività (Strava, Garmin, FitnessData).
/// Usato da StravaActivityCard, CompactActivityCard, GarminActivityDetailCard.
class ActivityUtils {
  ActivityUtils._();

  /// Icona per tipo attività (run, ride, swim, walk, hike, workout).
  static IconData getActivityIcon(String type) {
    final t = type.toLowerCase();
    if (t.contains('run') || t.contains('trail')) return Icons.directions_run;
    if (t.contains('ride') || t.contains('bike') || t.contains('cycle')) {
      return Icons.directions_bike;
    }
    if (t.contains('swim')) return Icons.pool;
    if (t.contains('walk') || t.contains('hike')) return Icons.directions_walk;
    if (t.contains('workout') || t.contains('weight') || t.contains('gym')) {
      return Icons.fitness_center;
    }
    return Icons.fitness_center;
  }

  /// Tipo attività formattato (Run, Ride, Swim, Walk, Hike, Workout).
  static String formatActivityType(String type, {String fallback = 'Workout'}) {
    final t = type.toLowerCase();
    if (t.contains('run')) return 'Run';
    if (t.contains('ride') || t.contains('bike') || t.contains('cycle')) {
      return 'Ride';
    }
    if (t.contains('swim')) return 'Swim';
    if (t.contains('walk')) return 'Walk';
    if (t.contains('hike')) return 'Hike';
    if (t.contains('workout') || t.contains('weight') || t.contains('gym')) {
      return 'Workout';
    }
    return type.isNotEmpty ? type : fallback;
  }

  /// Durata da secondi (es. 3661 → "1 h 1 min").
  static String formatDurationSeconds(int seconds) {
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    return h > 0 ? '$h h $m min' : '$m min';
  }

  /// Durata da minuti (es. 61.5 → "1 h 2 min").
  static String formatDurationMinutes(double minutes) {
    final m = minutes.round();
    final h = m ~/ 60;
    final min = m % 60;
    return h > 0 ? '$h h $min min' : '$min min';
  }

  
}


class MyCustomScrollBehavior extends MaterialScrollBehavior {
  // Consente lo scroll trascinando con il mouse (fondamentale su Windows)
  @override
  Set<PointerDeviceKind> get dragDevices => {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
        PointerDeviceKind.trackpad,
      };
}