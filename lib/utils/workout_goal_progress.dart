import 'package:fitai_analyzer/models/ai_current_allenamenti_model.dart';
import 'package:fitai_analyzer/models/fitness_data.dart';

/// Stima 0–1 dei minuti di movimento registrati vs obiettivo durata giornaliero.
double heuristicWorkoutProgress01({
  required AiCurrentAllenamentiModel? goal,
  required List<FitnessData> todayActivities,
}) {
  if (goal == null || todayActivities.isEmpty) return 0;
  final targetMin =
      goal.durataMins > 0 ? goal.durataMins.toDouble() : 45.0;
  var done = 0.0;
  for (final a in todayActivities) {
    final m = a.stravaElapsedMinutes;
    done += m > 0 ? m : (a.activeMinutes ?? 0);
  }
  if (done <= 0) {
    done = todayActivities.length * 15.0;
  }
  return (done / targetMin).clamp(0.0, 1.0);
}

/// Mostra quanto caricato dall'AI dopo sync locale: non sottoestimate se l'utente aggiunge attività.
double workoutProgressForDisplay({
  required AiCurrentAllenamentiModel? goal,
  required List<FitnessData> todayActivities,
}) {
  final est = heuristicWorkoutProgress01(
    goal: goal,
    todayActivities: todayActivities,
  );
  final ai = goal?.progressAgainstGoal01;
  if (ai == null) return est;
  return est > ai ? est : ai;
}
