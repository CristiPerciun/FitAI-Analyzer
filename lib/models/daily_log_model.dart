import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:json_annotation/json_annotation.dart';

part 'daily_log_model.g.dart';

/// Livello 1 - Log giornaliero (daily_logs/{YYYY-MM-DD}).
/// Indice giornaliero per UI/AI: activity_ids, health_ref, nutrition_summary, note.
/// Strategia Tre Livelli: nutrition_summary per Livello 2/3, meals subcollection per Livello 1.
@JsonSerializable()
class DailyLogModel {
  /// Data in formato YYYY-MM-DD (usata come doc ID).
  final String date;

  /// ID attività unificate del giorno (`users/{uid}/activities/{activityId}`).
  @JsonKey(name: 'activity_ids', defaultValue: [])
  final List<String> activityIds;

  /// Riferimento logico a `daily_health/{date}`.
  @JsonKey(name: 'health_ref')
  final String? healthRef;

  /// Note utente opzionali per il giorno.
  @JsonKey(name: 'user_notes', defaultValue: '')
  final String userNotes;

  /// Campi legacy embedded, mantenuti solo per retrocompatibilità in lettura.
  @JsonKey(name: 'strava_activities', defaultValue: [])
  final List<Map<String, dynamic>> stravaActivities;

  /// Campi legacy embedded, mantenuti solo per retrocompatibilità in lettura.
  @JsonKey(name: 'garmin_activities', defaultValue: [])
  final List<Map<String, dynamic>> garminActivities;

  /// Nutrizione da Gemini (foto piatto): total_calories, protein_g, carbs_g, etc.
  /// Retrocompatibilità: usato se nutrition_summary assente.
  @JsonKey(name: 'nutrition_gemini', defaultValue: {})
  final Map<String, dynamic> nutritionGemini;

  /// Sintesi nutrizione per Livello 2/3: total_kcal, total_protein, avg_longevity_score.
  /// L'IA legge solo questo per trend settimanale senza scaricare ogni pasto.
  @JsonKey(name: 'nutrition_summary', defaultValue: {})
  final Map<String, dynamic> nutritionSummary;

  /// Calorie bruciate totali (da attività).
  @JsonKey(name: 'total_burned_kcal', defaultValue: 0.0)
  final double totalBurnedKcal;

  /// Peso del giorno (opzionale).
  @JsonKey(name: 'weight_kg')
  final double? weightKg;

  /// Obiettivo del giorno creato dall'IA (L'app crea i goal giornalieri dal risultato AI).
  @JsonKey(name: 'goal_today_ia', defaultValue: '')
  final String goalTodayIa;

  @JsonKey(fromJson: _timestampFromJson, toJson: _timestampToJson)
  final DateTime timestamp;

  const DailyLogModel({
    required this.date,
    this.activityIds = const [],
    this.healthRef,
    this.userNotes = '',
    required this.stravaActivities,
    this.garminActivities = const [],
    required this.nutritionGemini,
    this.nutritionSummary = const {},
    required this.totalBurnedKcal,
    this.weightKg,
    required this.goalTodayIa,
    required this.timestamp,
  });

  /// Tipo attività normalizzato per confronto (Strava: sport_type/type, Garmin: activityTypeKey/activityType).
  static String _normalizedType(Map<String, dynamic> act) {
    final src = act['source']?.toString();
    if (src == 'garmin') {
      final tk = act['activityTypeKey']?.toString();
      if (tk != null && tk.isNotEmpty) {
        return tk.toLowerCase().replaceAll(' ', '_');
      }
      final t = act['activityType'];
      if (t is Map) {
        return ((t['typeKey'] ?? t['typeId'])?.toString() ?? '').toLowerCase();
      }
      return (t?.toString() ?? '').toLowerCase().replaceAll(' ', '_');
    }
    final t = (act['sport_type'] ?? act['type'] ?? '').toString().toLowerCase();
    return t;
  }

  /// True se Strava [s] è duplicato di Garmin [g]: stessa data, stesso tipo, ora/distanza simili.
  static bool _isStravaDuplicateOf(
    Map<String, dynamic> s,
    Map<String, dynamic> g,
  ) {
    if (_normalizedType(s).isEmpty || _normalizedType(g).isEmpty) return false;
    if (!_sameActivityType(_normalizedType(s), _normalizedType(g))) {
      return false;
    }
    final startS = s['start_date'] ?? s['start_date_local']?.toString() ?? '';
    final startG =
        g['startTimeGMT'] ??
        g['startTime'] ??
        g['startTimeLocal']?.toString() ??
        '';
    if (startS.isEmpty || startG.isEmpty) return false;
    try {
      final dtS = DateTime.parse(startS.toString().replaceFirst('Z', ''));
      final dtG = DateTime.parse(startG.toString().replaceFirst('Z', ''));
      if (dtS.difference(dtG).abs().inMinutes > 15) return false;
    } catch (_) {
      return false;
    }
    final distS = (s['distance'] as num?)?.toDouble() ?? 0;
    final distG = (g['distance'] as num?)?.toDouble() ?? 0;
    if (distS > 0 && distG > 0) {
      final ratio = distS / distG;
      if (ratio < 0.85 || ratio > 1.15) return false;
    }
    return true;
  }

  static bool _sameActivityType(String ts, String tg) {
    const runLike = ['run', 'running'];
    const rideLike = ['ride', 'cycling', 'bike', 'virtualride'];
    const walkLike = ['walk', 'walking', 'hike', 'hiking'];
    if (runLike.contains(ts) && runLike.contains(tg)) return true;
    if (rideLike.contains(ts) && rideLike.contains(tg)) return true;
    if (walkLike.contains(ts) && walkLike.contains(tg)) return true;
    return ts == tg;
  }

  /// Attività unificate per aggregazione (Strava + Garmin).
  /// Se il documento è già migrato, l'elenco vero sta in `activity_ids` e viene
  /// letto dalla collection `activities`; questo getter resta solo come fallback.
  List<Map<String, dynamic>> get activitiesForAggregation {
    if (garminActivities.isEmpty) return stravaActivities;
    final usedGarmin = List<bool>.filled(garminActivities.length, false);
    final stravaFiltered = stravaActivities.where((s) {
      for (var i = 0; i < garminActivities.length; i++) {
        if (usedGarmin[i]) continue;
        if (_isStravaDuplicateOf(s, garminActivities[i])) {
          usedGarmin[i] = true;
          return false; // Strava è duplicato di questa Garmin
        }
      }
      return true;
    }).toList();
    return [...garminActivities, ...stravaFiltered];
  }

  /// Calorie bruciate da attività unificate (con deduplicazione).
  double get totalBurnedKcalForAggregation {
    if (totalBurnedKcal > 0) return totalBurnedKcal;
    return activitiesForAggregation.fold<double>(
      0,
      (s, a) => s + ((a['calories'] as num?)?.toDouble() ?? 0),
    );
  }

  int get activityCountForAi {
    if (activityIds.isNotEmpty) return activityIds.length;
    return activitiesForAggregation.length;
  }

  /// Nutrizione per prompt AI: preferisce nutrition_summary (Livello 2/3), fallback a nutrition_gemini.
  Map<String, dynamic> get nutritionForAi {
    if (nutritionSummary.isNotEmpty) {
      return {
        'total_calories': nutritionSummary['total_kcal'],
        'protein_g': nutritionSummary['total_protein'],
        'carbs_g': nutritionSummary['total_carbs'],
        'fat_g': nutritionSummary['total_fat'],
        'avg_longevity_score': nutritionSummary['avg_longevity_score'],
      };
    }
    return nutritionGemini;
  }

  factory DailyLogModel.fromJson(Map<String, dynamic> json) =>
      _$DailyLogModelFromJson(json);

  Map<String, dynamic> toJson() => _$DailyLogModelToJson(this);

  static DateTime _timestampFromJson(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is String) return DateTime.tryParse(value) ?? DateTime.now();
    return DateTime.now();
  }

  static Object _timestampToJson(DateTime date) => Timestamp.fromDate(date);
}
