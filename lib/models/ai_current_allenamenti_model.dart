import 'package:cloud_firestore/cloud_firestore.dart';

/// Obiettivo di allenamento giornaliero generato dall'AI (prompt unificato).
/// Salvato in `users/{uid}/ai_current/allenamenti`.
/// Mostra la card "Obiettivo allenamento di oggi" nella pagina Allenamenti.
class AiCurrentAllenamentiModel {
  const AiCurrentAllenamentiModel({
    required this.tipo,
    required this.descrizione,
    this.durataMins = 0,
    this.intensita = '',
    this.forDate = '',
    this.progressAgainstGoal01,
    this.doneTodaySummary = '',
  });

  final String tipo;
  final String descrizione;
  final int durataMins;
  final String intensita;

  /// Data YYYY-MM-DD per cui è stato generato l'obiettivo.
  final String forDate;

  /// 0–1: quanto l'obiettivo giornaliero risulta coperto da attività già registrate oggi.
  final double? progressAgainstGoal01;

  /// Riconoscimento testuale (es. allenamento già fatto); max ~200 caratteri lato prompt.
  final String doneTodaySummary;

  bool get hasContent => descrizione.isNotEmpty || tipo.isNotEmpty;

  /// Parsing dalla chiave `"allenamento"` del JSON unificato restituito da Gemini.
  factory AiCurrentAllenamentiModel.fromUnifiedJson(
    Map<String, dynamic> unifiedJson,
    String forDate,
  ) {
    final raw = unifiedJson['allenamento'];
    final m = raw is Map<String, dynamic> ? raw : <String, dynamic>{};
    return AiCurrentAllenamentiModel(
      tipo: m['tipo']?.toString() ?? '',
      descrizione: m['descrizione']?.toString() ?? '',
      durataMins: (m['durata_min'] as num?)?.toInt() ?? 0,
      intensita: m['intensita']?.toString() ?? '',
      forDate: forDate,
      progressAgainstGoal01: _progress01FromJson(m['progress_against_goal_0_1']),
      doneTodaySummary:
          m['done_today_summary']?.toString() ?? '',
    );
  }

  static double? _progress01FromJson(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble().clamp(0.0, 1.0);
    return double.tryParse(v.toString().trim().replaceAll(',', '.'))?.clamp(
          0.0,
          1.0,
        );
  }

  factory AiCurrentAllenamentiModel.fromFirestore(Map<String, dynamic> data) {
    return AiCurrentAllenamentiModel(
      tipo: data['tipo']?.toString() ?? '',
      descrizione: data['descrizione']?.toString() ?? '',
      durataMins: (data['durata_min'] as num?)?.toInt() ?? 0,
      intensita: data['intensita']?.toString() ?? '',
      forDate: data['for_date']?.toString() ?? '',
      progressAgainstGoal01:
          _progress01FromJson(data['progress_against_goal_0_1']),
      doneTodaySummary: data['done_today_summary']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toFirestore() {
    final out = <String, dynamic>{
      'tipo': tipo,
      'descrizione': descrizione,
      'durata_min': durataMins,
      'intensita': intensita,
      'for_date': forDate,
      'updated_at': FieldValue.serverTimestamp(),
    };
    if (progressAgainstGoal01 != null) {
      out['progress_against_goal_0_1'] = progressAgainstGoal01;
    }
    if (doneTodaySummary.isNotEmpty) {
      out['done_today_summary'] = doneTodaySummary;
    }
    return out;
  }
}
