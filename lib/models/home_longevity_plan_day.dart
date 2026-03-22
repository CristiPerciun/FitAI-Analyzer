import 'package:cloud_firestore/cloud_firestore.dart';

/// Data locale `YYYY-MM-DD` (non UTC da `toIso8601String`).
String localCalendarDateKey([DateTime? d]) {
  final n = d ?? DateTime.now();
  final y = n.year.toString().padLeft(4, '0');
  final m = n.month.toString().padLeft(2, '0');
  final day = n.day.toString().padLeft(2, '0');
  return '$y-$m-$day';
}

/// Piano longevità Home (prompt master) salvato al massimo una volta al giorno
/// in `users/{uid}/home_longevity_plan/daily`.
class HomeLongevityPlanDay {
  const HomeLongevityPlanDay({
    required this.forDate,
    required this.pillars,
    this.weeklySprint,
    this.strategicAdvice,
  });

  final String forDate;
  final Map<String, String> pillars;
  final String? weeklySprint;
  final String? strategicAdvice;

  static const pillarFirestoreKeys = [
    'cuore',
    'forza',
    'alimentazione',
    'recupero',
  ];

  factory HomeLongevityPlanDay.fromGeminiJson(
    Map<String, dynamic> decoded,
    String forDate,
  ) {
    final pillars = <String, String>{};
    for (final k in pillarFirestoreKeys) {
      final v = decoded[k]?.toString();
      if (v != null && v.trim().isNotEmpty) pillars[k] = v.trim();
    }
    return HomeLongevityPlanDay(
      forDate: forDate,
      pillars: pillars,
      weeklySprint: _trimOrNull(decoded['weekly_sprint']?.toString()),
      strategicAdvice: _trimOrNull(decoded['strategic_advice']?.toString()),
    );
  }

  factory HomeLongevityPlanDay.fromFirestore(Map<String, dynamic> data) {
    final pillars = <String, String>{};
    for (final k in pillarFirestoreKeys) {
      final v = data[k]?.toString();
      if (v != null && v.trim().isNotEmpty) pillars[k] = v.trim();
    }
    return HomeLongevityPlanDay(
      forDate: data['for_date']?.toString() ?? '',
      pillars: pillars,
      weeklySprint: _trimOrNull(data['weekly_sprint']?.toString()),
      strategicAdvice: _trimOrNull(data['strategic_advice']?.toString()),
    );
  }

  static String? _trimOrNull(String? s) {
    if (s == null) return null;
    final t = s.trim();
    return t.isEmpty ? null : t;
  }

  Map<String, dynamic> toFirestoreMap() {
    final m = <String, dynamic>{
      'for_date': forDate,
      if (weeklySprint != null) 'weekly_sprint': weeklySprint,
      if (strategicAdvice != null) 'strategic_advice': strategicAdvice,
      'updated_at': FieldValue.serverTimestamp(),
    };
    for (final e in pillars.entries) {
      m[e.key] = e.value;
    }
    return m;
  }
}
