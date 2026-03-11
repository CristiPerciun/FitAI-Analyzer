import 'package:fitai_analyzer/models/fitness_data.dart';

/// Dati demo che simulano Health Connect / Garmin / Apple Health.
/// Usa quando non hai Apple ID o connessioni OAuth per continuare lo sviluppo.
const bool kUseDemoData = true;

/// Genera dati passi simulati (ultimi 7 giorni, stile Garmin).
List<FitnessData> getDemoGarminData() {
  final now = DateTime.now();
  return List.generate(7, (i) {
    final date = now.subtract(Duration(days: 6 - i));
    final steps = 3000.0 + (i * 800) + (i % 3) * 500; // Variabile 3k-8k
    return FitnessData(
      id: 'demo_garmin_$i',
      source: 'garmin',
      date: date,
      steps: steps,
      calories: steps * 0.04,
      distanceKm: steps / 1300,
      activeMinutes: steps / 100,
      raw: {'demo': true},
    );
  });
}

/// Genera dati calorie simulate (ultimi 7 giorni, stile Apple Health).
List<FitnessData> getDemoHealthData() {
  final now = DateTime.now();
  return List.generate(7, (i) {
    final date = now.subtract(Duration(days: 6 - i));
    final calories = 1800.0 + (i % 4) * 200; // 1800-2600 kcal
    return FitnessData(
      id: 'demo_health_$i',
      source: 'health',
      date: date,
      calories: calories,
      steps: 5000.0 + i * 300,
      activeMinutes: 25.0 + i * 5,
      raw: {'demo': true},
    );
  });
}
