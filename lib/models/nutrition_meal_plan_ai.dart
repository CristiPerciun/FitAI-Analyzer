import 'package:cloud_firestore/cloud_firestore.dart';

/// Risposta strutturata Gemini per gli obiettivi pasto giornalieri.
/// Salvata in `users/{uid}/ai_current/meal`.
/// Usata dalla pagina Alimentazione e generata dal prompt unificato giornaliero.
class NutritionMealPlanAi {
  const NutritionMealPlanAi({
    required this.obiettiviColazione,
    required this.obiettiviPranzo,
    required this.obiettiviCena,
    this.macroGiornalieri = const {},
    this.consigliIntegratori = '',
    this.aderenzaScore,
    this.noteLongevita = '',
    this.pianoSettimanale = const [],
  });

  final List<String> obiettiviColazione;
  final List<String> obiettiviPranzo;
  final List<String> obiettiviCena;
  final Map<String, dynamic> macroGiornalieri;
  final String consigliIntegratori;
  final int? aderenzaScore;
  final String noteLongevita;
  final List<dynamic> pianoSettimanale;

  bool get hasAnyObjective =>
      obiettiviColazione.isNotEmpty ||
      obiettiviPranzo.isNotEmpty ||
      obiettiviCena.isNotEmpty;

  static List<String> _stringList(dynamic v) {
    if (v is! List) return [];
    return v
        .map((e) => e?.toString().trim() ?? '')
        .where((s) => s.isNotEmpty)
        .toList();
  }

  /// Parsing risposta Gemini (JSON root).
  factory NutritionMealPlanAi.fromGeminiMap(Map<String, dynamic> json) {
    final perPasto = json['obiettivi_per_pasto'];
    Map<String, dynamic>? m;
    if (perPasto is Map) {
      m = Map<String, dynamic>.from(perPasto);
    }

    List<String> fromPasto(String k1, String k2) {
      if (m == null) return [];
      final v = m[k1] ?? m[k2];
      return _stringList(v);
    }

    final macroRaw = json['macro_giornalieri'];
    final macro = macroRaw is Map
        ? Map<String, dynamic>.from(macroRaw)
        : <String, dynamic>{};

    final scoreRaw = json['aderenza_score'];
    int? score;
    if (scoreRaw is num) {
      score = scoreRaw.round();
    } else if (scoreRaw != null) {
      score = int.tryParse(scoreRaw.toString());
    }

    final piano = json['piano_settimanale'];
    final pianoList = piano is List ? piano : <dynamic>[];

    return NutritionMealPlanAi(
      obiettiviColazione: fromPasto('colazione', 'Colazione'),
      obiettiviPranzo: fromPasto('pranzo', 'Pranzo'),
      obiettiviCena: fromPasto('cena', 'Cena'),
      macroGiornalieri: macro,
      consigliIntegratori: json['consigli_integratori']?.toString() ?? '',
      aderenzaScore: score,
      noteLongevita: json['note_longevita']?.toString() ?? '',
      pianoSettimanale: pianoList,
    );
  }

  /// Parsing dalla chiave `"meal"` del JSON unificato restituito da Gemini.
  factory NutritionMealPlanAi.fromUnifiedJson(
    Map<String, dynamic> unifiedJson,
  ) {
    final raw = unifiedJson['meal'];
    final m = raw is Map<String, dynamic> ? raw : <String, dynamic>{};
    final macroRaw = m['macro_target'];
    final macro = macroRaw is Map
        ? Map<String, dynamic>.from(macroRaw)
        : <String, dynamic>{};
    return NutritionMealPlanAi(
      obiettiviColazione: _stringList(m['colazione']),
      obiettiviPranzo: _stringList(m['pranzo']),
      obiettiviCena: _stringList(m['cena']),
      macroGiornalieri: macro,
      consigliIntegratori: m['consigli_integratori']?.toString() ?? '',
      noteLongevita: m['note']?.toString() ?? '',
    );
  }

  factory NutritionMealPlanAi.fromFirestore(Map<String, dynamic> data) {
    return NutritionMealPlanAi(
      obiettiviColazione: _stringList(data['obiettivi_colazione']),
      obiettiviPranzo: _stringList(data['obiettivi_pranzo']),
      obiettiviCena: _stringList(data['obiettivi_cena']),
      macroGiornalieri: data['macro_giornalieri'] is Map
          ? Map<String, dynamic>.from(data['macro_giornalieri'] as Map)
          : {},
      consigliIntegratori: data['consigli_integratori']?.toString() ?? '',
      aderenzaScore: (data['aderenza_score'] as num?)?.round(),
      noteLongevita: data['note_longevita']?.toString() ?? '',
      pianoSettimanale: data['piano_settimanale'] is List
          ? List<dynamic>.from(data['piano_settimanale'] as List)
          : [],
    );
  }

  Map<String, dynamic> toFirestore({String? forDate}) {
    return {
      'obiettivi_colazione': obiettiviColazione,
      'obiettivi_pranzo': obiettiviPranzo,
      'obiettivi_cena': obiettiviCena,
      'macro_giornalieri': macroGiornalieri,
      'consigli_integratori': consigliIntegratori,
      if (aderenzaScore != null) 'aderenza_score': aderenzaScore,
      'note_longevita': noteLongevita,
      'piano_settimanale': pianoSettimanale,
      if (forDate case final d?) 'for_date': d,
      'updated_at': FieldValue.serverTimestamp(),
    };
  }
}
