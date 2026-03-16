/// Modello per dati giornalieri Garmin da Firestore (garmin_daily/{date}).
/// Scritto dal garmin-sync-server Python su fly.io.
/// Contiene stats, heartRate, sleep del giorno.
class GarminDailyModel {
  final String date; // YYYY-MM-DD
  final Map<String, dynamic>? stats;
  final Map<String, dynamic>? heartRate;
  final Map<String, dynamic>? sleep;
  final String? syncedAt;

  const GarminDailyModel({
    required this.date,
    this.stats,
    this.heartRate,
    this.sleep,
    this.syncedAt,
  });

  factory GarminDailyModel.fromFirestore(Map<String, dynamic> data, String docId) {
    return GarminDailyModel(
      date: data['date']?.toString() ?? docId,
      stats: data['stats'] as Map<String, dynamic>?,
      heartRate: data['heartRate'] as Map<String, dynamic>?,
      sleep: data['sleep'] as Map<String, dynamic>?,
      syncedAt: data['syncedAt']?.toString(),
    );
  }
}
