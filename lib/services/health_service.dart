import 'package:fitai_analyzer/models/fitness_data.dart';
import 'package:fitai_analyzer/services/health_platform_stub.dart'
    if (dart.library.io) 'package:fitai_analyzer/services/health_platform_io.dart'
    as hp;
import 'package:health/health.dart';

/// Servizio per leggere dati da Apple Health (iOS) e Health Connect (Android).
/// Su Android per ora ritorna lista vuota (da configurare Health Connect).
class HealthService {
  final Health _health = Health();

  static final List<HealthDataType> _types = [
    HealthDataType.STEPS,
    HealthDataType.ACTIVE_ENERGY_BURNED,
    HealthDataType.SLEEP_ASLEEP,
    HealthDataType.HEART_RATE,
    HealthDataType.DISTANCE_WALKING_RUNNING,
    HealthDataType.FLIGHTS_CLIMBED,
  ];

  /// Configura il plugin (da chiamare prima di requestPermissions/fetchData).
  /// Se HealthKit non è disponibile (es. provisioning senza capability), lancia.
  Future<void> configure() async {
    try {
      await _health.configure();
    } catch (e) {
      throw StateError(
        'HealthKit configure fallito. Errore originale: $e\n'
        'Possibili cause: app installata con Sideloadly + Apple ID gratuito, '
        'HealthKit non abilitato nel provisioning profile.',
      );
    }
  }

  /// Richiede autorizzazione per i tipi di dati health.
  /// Usa HealthDataAccess.READ per lettura sola (best practice Apple).
  /// Se la schermata Health non appare, di solito significa che HealthKit
  /// non è disponibile (es. app installata con Sideloadly + Apple ID gratuito).
  Future<bool> requestPermissions() async {
    if (!hp.isIOS) {
      // Android/Web: Health Connect richiede setup aggiuntivo, per ora ritorna false
      return false;
    }
    try {
      await _health.configure();
      final permissions = List.filled(_types.length, HealthDataAccess.READ);
      return await _health.requestAuthorization(_types, permissions: permissions);
    } catch (e) {
      // Propaga l'errore reale invece di nasconderlo: aiuta a capire
      // se HealthKit non è disponibile (es. provisioning senza capability)
      throw StateError(
        'HealthKit non disponibile. Errore: $e\n'
        'Se la schermata Apple Health non è mai apparsa, l\'app potrebbe essere '
        'installata con Apple ID gratuito (Sideloadly). HealthKit richiede un '
        'account Apple Developer a pagamento (\$99/anno).',
      );
    }
  }

  /// Legge gli ultimi 7 giorni e mappa su FitnessData (source = 'health').
  /// Su Android/Web ritorna lista vuota.
  Future<List<FitnessData>> fetchData() async {
    final result = await fetchDataWithRaw();
    return result.$2;
  }

  /// Come fetchData ma restituisce anche la risposta raw da HealthKit (per debug).
  /// Ritorna (rawJson, processedData).
  /// Se getHealthDataFromTypes fallisce, propaga l'errore reale.
  Future<(List<Map<String, dynamic>>, List<FitnessData>)> fetchDataWithRaw() async {
    if (!hp.isIOS) {
      return (<Map<String, dynamic>>[], <FitnessData>[]);
    }
    try {
      await _health.configure();
      final now = DateTime.now();
      final start = now.subtract(const Duration(days: 7));
      final points = await _health.getHealthDataFromTypes(
        types: _types,
        startTime: start,
        endTime: now,
      );
      final rawJson = points.map((p) => p.toJson()).toList();
      final processed = _mapToFitnessData(points, start, now);
      return (rawJson, processed);
    } catch (e) {
      throw StateError(
        'Lettura dati HealthKit fallita. Errore originale: $e\n'
        'Tipi richiesti: ${_types.map((t) => t.name).join(", ")}',
      );
    }
  }

  List<FitnessData> _mapToFitnessData(
    List<HealthDataPoint> points,
    DateTime start,
    DateTime end,
  ) {
    final byDate = <DateTime, Map<String, double>>{};
    for (var d = DateTime(start.year, start.month, start.day);
        !d.isAfter(DateTime(end.year, end.month, end.day));
        d = d.add(const Duration(days: 1))) {
      byDate[d] = {
        'steps': 0,
        'calories': 0,
        'sleepMinutes': 0,
        'heartRate': 0,
        'heartRateCount': 0,
        'distanceKm': 0,
        'floors': 0,
      };
    }

    for (final p in points) {
      final date = DateTime(p.dateFrom.year, p.dateFrom.month, p.dateFrom.day);
      final map = byDate[date];
      if (map == null) continue;

      final numVal = p.value is NumericHealthValue
          ? (p.value as NumericHealthValue).numericValue.toDouble()
          : 0.0;

      switch (p.type) {
        case HealthDataType.STEPS:
          map['steps'] = (map['steps'] ?? 0) + numVal;
          break;
        case HealthDataType.ACTIVE_ENERGY_BURNED:
          map['calories'] = (map['calories'] ?? 0) + numVal;
          break;
        case HealthDataType.SLEEP_ASLEEP:
          map['sleepMinutes'] = (map['sleepMinutes'] ?? 0) + numVal;
          break;
        case HealthDataType.HEART_RATE:
          map['heartRate'] = (map['heartRate'] ?? 0) + numVal;
          map['heartRateCount'] = (map['heartRateCount'] ?? 0) + 1;
          break;
        case HealthDataType.DISTANCE_WALKING_RUNNING:
          map['distanceKm'] = (map['distanceKm'] ?? 0) + (numVal / 1000);
          break;
        case HealthDataType.FLIGHTS_CLIMBED:
          map['floors'] = (map['floors'] ?? 0) + numVal;
          break;
        default:
          break;
      }
    }

    return byDate.entries.map((e) {
      final d = e.value;
      final steps = d['steps'] ?? 0;
      final calories = d['calories'] ?? 0;
      final hrCount = d['heartRateCount'] ?? 0;
      final avgHr = hrCount > 0 ? (d['heartRate'] ?? 0) / hrCount : 0.0;
      final dist = d['distanceKm'] ?? 0;
      final sleepMin = d['sleepMinutes'] ?? 0;
      return FitnessData(
        id: 'health_${e.key.toIso8601String().split('T').first}',
        source: 'health',
        date: e.key,
        steps: steps > 0 ? steps : null,
        calories: calories > 0 ? calories : null,
        distanceKm: dist > 0 ? dist : null,
        activeMinutes: null,
        raw: {
          'sleepMinutes': sleepMin > 0 ? sleepMin : null,
          'heartRate': avgHr > 0 ? avgHr : null,
          'floors': (d['floors'] ?? 0) > 0 ? d['floors'] : null,
        },
      );
    }).toList()
      ..sort((a, b) => a.date.compareTo(b.date));
  }
}
