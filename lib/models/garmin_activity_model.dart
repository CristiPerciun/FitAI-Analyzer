/// Modello per attività Garmin da Firestore (garmin_activities).
/// Scritto dal garmin-sync-server Python su fly.io.
class GarminActivityModel {
  final String activityId;
  final String startTime; // ISO string (startTimeGMT)
  final String activityType;
  final double? distance; // metri
  final double? duration; // secondi
  final double? averageHR;
  final double? calories;
  final Map<String, dynamic>? rawData;
  final String? syncedAt;

  const GarminActivityModel({
    required this.activityId,
    required this.startTime,
    required this.activityType,
    this.distance,
    this.duration,
    this.averageHR,
    this.calories,
    this.rawData,
    this.syncedAt,
  });

  factory GarminActivityModel.fromFirestore(Map<String, dynamic> data, String docId) {
    final typeStr = data['activityTypeKey']?.toString() ??
        (data['activityType'] is Map
            ? (data['activityType']['typeKey'] ?? data['activityType']['typeId'])?.toString()
            : data['activityType']?.toString());
    return GarminActivityModel(
      activityId: data['activityId']?.toString() ?? data['activityID']?.toString() ?? docId,
      startTime: data['startTime']?.toString() ??
          data['startTimeGMT']?.toString() ??
          data['startTimeLocal']?.toString() ??
          '',
      activityType: typeStr ?? 'unknown',
      distance: (data['distance'] as num?)?.toDouble(),
      duration: (data['duration'] as num?)?.toDouble() ??
          (data['movingDuration'] as num?)?.toDouble(),
      averageHR: (data['averageHR'] as num?)?.toDouble() ??
          (data['averageHeartRate'] as num?)?.toDouble(),
      calories: (data['calories'] as num?)?.toDouble(),
      rawData: data['rawData'] as Map<String, dynamic>? ?? data,
      syncedAt: data['syncedAt']?.toString(),
    );
  }

  /// Data in formato YYYY-MM-DD per raggruppamento.
  String get dateKey {
    final dt = DateTime.tryParse(startTime);
    if (dt == null) return '';
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
  }

  DateTime? get startDateTime => DateTime.tryParse(startTime);

  double get distanceKm => (distance ?? 0) / 1000;

  double get activeMinutes => (duration ?? 0) / 60;
}
