import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/ai_current_allenamenti_model.dart';
import '../models/baseline_profile_model.dart';
import '../models/daily_log_model.dart';
import '../models/home_longevity_plan_day.dart' show HomeLongevityPlanDay, localCalendarDateKey;
import '../models/longevity_home_package.dart';
import '../models/nutrition_meal_plan_ai.dart';
import '../models/rolling_10days_model.dart';
import '../models/user_profile.dart';

final longevityEngineProvider = Provider<LongevityEngine>(
  (ref) => LongevityEngine(),
);

/// Engine che aggrega dati da Livello 1 (daily_logs), Livello 2 (rolling_10days)
/// e Livello 3 (baseline_profile) per creare un unico pacchetto informativo
/// da inviare all'AI per popolare la Home.
///
/// Rispetta la strategia Tre Livelli: non legge sottocollezioni (meals),
/// usa solo campi di sintesi (nutrition_summary) per Livello 2/3.
class LongevityEngine {
  final _firestore = FirebaseFirestore.instance;

  /// Costruisce il pacchetto informativo unificato per la Home.
  /// Esegue 3 letture Firestore in parallelo (daily_logs oggi, rolling_10days, baseline_profile).
  Future<LongevityHomePackage> buildHomePackage(String uid) async {
    final todayStr = DateTime.now().toIso8601String().split('T')[0];

    final results = await Future.wait([
      _getTodayLog(uid, todayStr),
      _getRolling10Days(uid),
      _getBaseline(uid),
    ]);

    return LongevityHomePackage(
      today: results[0] as DailyLogModel?,
      rolling: results[1] as Rolling10DaysModel?,
      baseline: results[2] as BaselineProfileModel?,
    );
  }

  /// Restituisce il prompt pronto per l'AI (output di buildAiPrompt sul pacchetto).
  /// Comodo per inviare direttamente a GeminiService.
  Future<String> buildHomeAiPrompt(String uid) async {
    final package = await buildHomePackage(uid);
    return package.buildAiPrompt();
  }

  /// Costruisce il contesto completo per Gemini: profilo, 2 mesi settimanali, 7 giorni dettagliati, note, diario longevità.
  Future<GeminiHomeContext> buildGeminiHomeContext(String uid) async {
    final today = DateTime.now();
    final twoMonthsAgo = today.subtract(const Duration(days: 60));
    final todayStr = today.toIso8601String().split('T')[0];

    final results = await Future.wait([
      _getUserProfile(uid),
      _getDailyLogsRange(
        uid,
        twoMonthsAgo.toIso8601String().split('T')[0],
        todayStr,
      ),
      _getActivitiesRange(
        uid,
        twoMonthsAgo.toIso8601String().split('T')[0],
        todayStr,
      ),
      _getDailyHealthRange(
        uid,
        twoMonthsAgo.toIso8601String().split('T')[0],
        todayStr,
      ),
      _getBaseline(uid),
      _getLongevityDiary(uid),
    ]);

    final dailyLogs = results[1] as List<DailyLogModel>;
    final activitiesByDate =
        results[2] as Map<String, List<Map<String, dynamic>>>;
    final dailyHealth = results[3] as List<Map<String, dynamic>>;
    final dailyHealthByDate = {
      for (final health in dailyHealth) (health['date'] as String): health,
    };

    return GeminiHomeContext(
      userProfile: results[0] as UserProfile?,
      detailed7Days: _buildDetailedLast7Days(
        today,
        dailyLogs: dailyLogs,
        activitiesByDate: activitiesByDate,
        dailyHealthByDate: dailyHealthByDate,
      ),
      weeklySummary: _buildWeeklyAggregatesTwoMonths(
        dailyLogs: dailyLogs,
        activitiesByDate: activitiesByDate,
        dailyHealth: dailyHealth,
      ),
      baseline: results[4] as BaselineProfileModel?,
      longevityDiary: results[5] as String,
    );
  }

  /// Legge il Diario della Longevità da `profile/diary`.
  /// Se manca, genera da baseline + rolling_10days e lo scrive.
  Future<String> _getLongevityDiary(String uid) async {
    final doc = await _firestore
        .collection('users')
        .doc(uid)
        .collection('profile')
        .doc('diary')
        .get();

    if (doc.exists) {
      final text = doc.data()?['diary_text']?.toString();
      if (text != null && text.isNotEmpty) return text;
    }

    return _generateAndSaveInitialDiary(uid);
  }

  /// Genera il diario iniziale da dati storici (baseline, rolling) e lo salva.
  Future<String> _generateAndSaveInitialDiary(String uid) async {
    final baseline = await _getBaseline(uid);
    final rolling = await _getRolling10Days(uid);
    final profile = await _getUserProfile(uid);

    final sb = StringBuffer();
    sb.writeln('# DIARIO EVOLUZIONE UTENTE');
    sb.writeln();
    sb.writeln('Questo diario contiene l\'andamento dell\'utente basato su dati reali:');
    sb.writeln('statistiche, attività, nutrizione, biometrici (passi, sonno, VO2Max, Fitness Age).');
    sb.writeln('Si aggiorna ad ogni analisi AI con l\'evoluzione del giorno.');
    sb.writeln();
    sb.writeln('---');
    sb.writeln();

    if (profile != null) {
      sb.writeln('## Profilo');
      sb.writeln(
        'Main goal: ${_mainGoalLabel(profile.mainGoal)} | Età: ${profile.age} | '
        'Peso: ${profile.weightKg} kg | Altezza: ${profile.heightCm} cm | '
        'Allenamenti/sett: ${profile.trainingDaysPerWeek} | Sonno medio: ${profile.avgSleepHours}h',
      );
      sb.writeln();
    }

    if (baseline != null) {
      sb.writeln('## Storico annuale');
      sb.writeln('Obiettivo prevalente: ${baseline.goalIa}');
      sb.writeln('Note evolutive: ${baseline.evolutionNotes}');
      if (baseline.annualStats.isNotEmpty) {
        sb.writeln(
          'Statistiche: ${baseline.annualStats.entries.map((e) => '${e.key}=${e.value}').join(', ')}',
        );
      }
      if (baseline.aiReadySummary.isNotEmpty) {
        sb.writeln();
        sb.writeln(baseline.aiReadySummary);
      }
      sb.writeln();
    }

    if (rolling != null) {
      sb.writeln('## Ultimi 10 giorni');
      sb.writeln(
        'Distanza: ${rolling.totalDistanceKm.toStringAsFixed(1)} km | '
        'Zone 2: ${rolling.totalZone2Minutes} min | '
        'VO2 stimato: ${rolling.estimatedVo2Max.toStringAsFixed(1)}',
      );
      final macro = rolling.macroAverages;
      if (macro.isNotEmpty) {
        sb.writeln(
          'Nutrizione media: ${macro['calories']?.round() ?? 0} kcal, '
          'P: ${macro['protein_g']?.round() ?? 0}g, '
          'C: ${macro['carbs_g']?.round() ?? 0}g, '
          'F: ${macro['fat_g']?.round() ?? 0}g',
        );
      }
      sb.writeln();
    }

    if (baseline == null && rolling == null) {
      sb.writeln('Nessun dato storico ancora. Sincronizza Strava/Garmin e registra pasti.');
    }

    final text = sb.toString();
    final todayStr = DateTime.now().toIso8601String().split('T')[0];
    await _firestore
        .collection('users')
        .doc(uid)
        .collection('profile')
        .doc('diary')
        .set({
      'diary_text': text,
      'last_updated': FieldValue.serverTimestamp(),
      'last_updated_date': todayStr,
    }, SetOptions(merge: true));

    return text;
  }

  /// Salva l'aggiornamento del Diario della Longevità in `profile/diary`.
  /// Appende historical_context_summary alla stringa esistente (evoluzione del giorno).
  Future<void> saveLongevityDiaryUpdate(
    String uid,
    String dateStr,
    Map<String, dynamic> databaseUpdate,
  ) async {
    final historical = databaseUpdate['historical_context_summary']?.toString();
    final trends = databaseUpdate['detected_trends']?.toString();
    final score = databaseUpdate['status_score'];

    if (historical == null && trends == null && score == null) return;

    final docRef = _firestore
        .collection('users')
        .doc(uid)
        .collection('profile')
        .doc('diary');

    final doc = await docRef.get();
    String currentText = doc.exists ? (doc.data()?['diary_text']?.toString() ?? '') : '';

    final entries = <String>[];
    if (historical != null && historical.isNotEmpty) {
      entries.add('[$dateStr] $historical');
    }
    if (trends != null && trends.isNotEmpty) {
      entries.add('[$dateStr] Trend: $trends');
    }
    if (score != null) {
      final n = score is num ? score.toInt() : int.tryParse(score.toString());
      if (n != null && n >= 1 && n <= 100) {
        entries.add('[$dateStr] Status score: $n/100');
      }
    }

    if (entries.isEmpty) return;

    final append = '\n\n${entries.join('\n')}';
    currentText = currentText.isEmpty ? entries.join('\n') : currentText + append;

    await docRef.set({
      'diary_text': currentText,
      'last_updated': FieldValue.serverTimestamp(),
      'last_updated_date': dateStr,
    }, SetOptions(merge: true));
  }

  // ============================================================
  // PROMPT UNIFICATO GIORNALIERO
  // ============================================================

  /// Obiettivo allenamento salvato (`ai_current/allenamenti`) solo se [for_date] coincide.
  Future<AiCurrentAllenamentiModel?> fetchAiCurrentAllenamentiForDate(
    String uid,
    String calendarDateYmd,
  ) async {
    final snap = await _firestore
        .collection('users')
        .doc(uid)
        .collection('ai_current')
        .doc('allenamenti')
        .get();
    if (!snap.exists || snap.data() == null) return null;
    final m = AiCurrentAllenamentiModel.fromFirestore(snap.data()!);
    if (m.forDate != calendarDateYmd) return null;
    return m;
  }

  /// Dopo un nuovo JSON AI, mantieni tipo/durata/intensità se c’è già un obiettivo valido per oggi.
  void mergeStableAllenamentoFromPrevious({
    required Map<String, dynamic> decoded,
    required AiCurrentAllenamentiModel? previousForSameCalendarDay,
    required String calendarDateYmd,
  }) {
    if (previousForSameCalendarDay == null ||
        previousForSameCalendarDay.forDate != calendarDateYmd ||
        !previousForSameCalendarDay.hasContent) {
      return;
    }
    final raw = decoded['allenamento'];
    if (raw is! Map<String, dynamic>) return;

    final p = previousForSameCalendarDay;
    if (p.tipo.trim().isNotEmpty) raw['tipo'] = p.tipo;
    if (p.durataMins > 0) raw['durata_min'] = p.durataMins;
    if (p.intensita.trim().isNotEmpty) raw['intensita'] = p.intensita;
  }

  /// Costruisce il contesto unificato per il prompt giornaliero.
  /// Riusa [buildGeminiHomeContext] per i dati storici (profilo, 2 mesi, 7 giorni, baseline, diario)
  /// e aggiunge [rolling_10days/current] + obiettivo allenamento già salvato per oggi (se esiste).
  Future<UnifiedDailyContext> buildUnifiedDailyContext(String uid) async {
    final nowLocal = DateTime.now();
    final todayStr = localCalendarDateKey(nowLocal);
    final yesterdayStr =
        localCalendarDateKey(nowLocal.subtract(const Duration(days: 1)));

    final results = await Future.wait([
      buildGeminiHomeContext(uid),
      _getRolling10Days(uid),
      fetchAiCurrentAllenamentiForDate(uid, todayStr),
    ]);

    final gemCtx = results[0] as GeminiHomeContext;
    final rolling = results[1] as Rolling10DaysModel?;
    final existingAllenamenti = results[2] as AiCurrentAllenamentiModel?;

    // L'elemento 0 di detailed7Days è il giorno più recente (oggi).
    final yesterdayDetail =
        gemCtx.detailed7Days.isNotEmpty ? gemCtx.detailed7Days.first : null;

    return UnifiedDailyContext(
      userProfile: gemCtx.userProfile,
      yesterdayDate: yesterdayStr,
      todayDate: todayStr,
      yesterdayLog: yesterdayDetail?.log,
      yesterdayActivities: yesterdayDetail?.activities ?? const [],
      yesterdayHealth: yesterdayDetail?.health,
      rolling: rolling,
      longevityDiary: gemCtx.longevityDiary,
      baseline: gemCtx.baseline,
      detailed7Days: gemCtx.detailed7Days,
      weekly2Months: gemCtx.weeklySummary,
      existingAllenamentiForToday: existingAllenamenti,
    );
  }

  /// Costruisce il prompt unificato giornaliero da inviare a Gemini.
  /// Integra il ricco contesto storico della vecchia analisi Home (profilo, 2 mesi settimanali,
  /// 7 giorni dettagliati, baseline notes, diario) con il nuovo schema JSON unificato
  /// che genera in un'unica risposta: obiettivi pasto, allenamento, home e aggiornamento diario.
  String buildUnifiedPromptFromContext(UnifiedDailyContext ctx) {
    final sb = StringBuffer();
    sb.writeln(
      '# CONTESTO PER OBIETTIVI GIORNALIERI — OGGI ${ctx.todayDate}',
    );
    sb.writeln();

    // --- Sezione 1: Profilo ---
    sb.writeln('## 1. PROFILO UTENTE (onboarding)');
    sb.writeln(_formatUserProfile(ctx.userProfile));
    sb.writeln();

    // --- Sezione 2: Baseline notes (obiettivo prevalente + evoluzione) ---
    sb.writeln('## 2. NOTE BASELINE (obiettivo prevalente + evoluzione annuale)');
    sb.writeln(_formatNotes(ctx.baseline));
    sb.writeln();

    // --- Sezione 3: Riassunto 2 mesi (medie settimanali) ---
    sb.writeln('## 3. RIASSUNTO 2 MESI (medie settimanali)');
    sb.writeln(_formatWeeklySummary(ctx.weekly2Months));
    sb.writeln();

    // --- Sezione 4: Ultimi 7 giorni in dettaglio ---
    sb.writeln(
      '## 4. DATI DETTAGLIATI ULTIMI 7 GIORNI (attività + biometrici Garmin)',
    );
    sb.writeln(_formatDetailed7Days(ctx.detailed7Days));
    sb.writeln();

    sb.writeln('## 4B. FOCUS OBBLIGATORIO — ATTIVITÀ GIÀ REGISTRATE OGGI');
    sb.writeln(_formatTodayPinnedActivities(ctx));
    sb.writeln();

    sb.writeln('## 4C. STABILITÀ OBIETTIVO ALLENAMENTO DELLA GIORNATA');
    sb.writeln(_formatExistingAllenamentoBlock(ctx.existingAllenamentiForToday));
    sb.writeln();

    // --- Sezione 5: Rolling 10 giorni ---
    sb.writeln('## 5. ROLLING ULTIMI 10 GIORNI (aggregato rapido)');
    if (ctx.rolling != null) {
      final r = ctx.rolling!;
      sb.writeln(
        'Distanza: ${r.totalDistanceKm.toStringAsFixed(1)} km | '
        'Zone 2: ${r.totalZone2Minutes} min | '
        'VO2 stimato: ${r.estimatedVo2Max.toStringAsFixed(1)} | '
        'FC media: ${r.avgHr.toStringAsFixed(0)} bpm',
      );
      final macro = r.macroAverages;
      if (macro.isNotEmpty) {
        sb.writeln(
          'Nutrizione media: ${macro['calories']?.round() ?? 0} kcal | '
          'P: ${macro['protein_g']?.round() ?? 0}g | '
          'C: ${macro['carbs_g']?.round() ?? 0}g | '
          'F: ${macro['fat_g']?.round() ?? 0}g',
        );
      }
    } else {
      sb.writeln('Nessun dato rolling disponibile.');
    }
    sb.writeln();

    // --- Sezione 6: Diario evoluzione ---
    sb.writeln('## 6. DIARIO EVOLUZIONE UTENTE (storia evolutiva)');
    sb.writeln(
      'Documento con la storia evolutiva dell\'utente: statistiche reali, '
      'andamento attività/nutrizione/biometrici. Si aggiorna ad ogni analisi.',
    );
    sb.writeln();
    sb.writeln(
      ctx.longevityDiary.isEmpty
          ? 'Diario vuoto. Questa è la prima analisi.'
          : ctx.longevityDiary,
    );
    sb.writeln();

    // --- Istruzioni prompt ---
    sb.writeln('---');
    sb.writeln(
      'MAIN GOAL (4 vie) DA RISPETTARE: ${_mainGoalLabel(ctx.userProfile?.mainGoal ?? '')}',
    );
    sb.writeln();
    sb.writeln(
      'Sei un esperto di longevità (Peter Attia, Outlive) e coach sportivo/nutrizionista.\n'
      'Basandoti su tutto il contesto sopra, genera in UN\'UNICA risposta JSON\n'
      'gli obiettivi personalizzati per OGGI (${ctx.todayDate}):\n'
      '1. Obiettivi pasto (colazione/pranzo/cena) con macro target\n'
      '2. Obiettivo di allenamento: se la sezione 4B lista attività già registrate oggi, riconoscile sempre in '
      'done_today_summary (tono positivo/breve) e proponi un focus COMPLEMENTARE (es. dopo cardio zona 2 — mobilità o forza leggera) '
      'o recupero quando appropriato — non suggerire di ripetere la stessa sessione come se non fosse avvenuta.\n'
      '3. Imposta progress_against_goal_0_1 tra 0 e 1 come stima ragionevole di quanto l\'obiettivo giornaliero '
      '(durata/intensità) è già coperto dalle attività GIÀ nella sezione 4B rispetto a tipo/durata_min che stai usando.\n'
      '4. Se la sezione 4C definisce già tipo/durata_min/intensita, RIUTILIZZA GLI STESSI VALORI e aggiorna solo '
      'descrizione/complementari, progress_against_goal_0_1 e done_today_summary.\n'
      '5. 4 micro-obiettivi Home (Cuore, Forza, Alimentazione, Recupero) + sprint settimanale + consiglio\n'
      '6. Sintesi dell\'EVOLUZIONE di oggi da appendere al diario (dati reali, NON consigli AI)\n'
      'Rispondi ESCLUSIVAMENTE in JSON valido, lingua italiana:',
    );
    sb.writeln();
    sb.writeln(r'''{
  "meal": {
    "colazione": ["obiettivo 1", "obiettivo 2"],
    "pranzo": ["obiettivo 1", "obiettivo 2"],
    "cena": ["obiettivo 1", "obiettivo 2"],
    "macro_target": {
      "proteine_g": 0,
      "carboidrati_g": 0,
      "grassi_g": 0,
      "kcal": 0
    },
    "consigli_integratori": "stringa o vuoto",
    "note": "max 1 frase longevità/nutrizione"
  },
  "allenamento": {
    "tipo": "es. Corsa Zone 2",
    "descrizione": "obiettivo per oggi o complementare, max ~200 caratteri",
    "durata_min": 0,
    "intensita": "leggera | moderata | intensa | riposo attivo",
    "progress_against_goal_0_1": 0.0,
    "done_today_summary": "breve messaggio motivazionale ciò che è già stato fatto oggi; stringa vuota se nulla registrato"
  },
  "home": {
    "cuore": "micro-obiettivo Zone 2/cardiovascolare, max 80 caratteri",
    "forza": "micro-obiettivo forza/muscolare, max 80 caratteri",
    "alimentazione": "micro-obiettivo nutrizione, max 80 caratteri",
    "recupero": "micro-obiettivo recupero/sonno/HRV, max 80 caratteri",
    "weekly_sprint": "macro-obiettivo settimanale 7 giorni, max 120 caratteri",
    "strategic_advice": "consiglio strategico a lungo termine basato su trend reali, max 200 caratteri"
  },
  "diary_update": {
    "historical_context_summary": "sintesi evoluzione di oggi basata su dati reali (cosa è successo: attività, nutrizione, metriche). Max 300 caratteri.",
    "detected_trends": "trend rilevati es. calo VO2Max, deficit proteico, miglioramento sonno",
    "status_score": 75
  }
}''');
    return sb.toString();
  }

  /// Salva il JSON unificato da Gemini nelle 3 sottocollezioni `ai_current/`
  /// e aggiorna `profile/diary`.
  Future<void> saveUnifiedAiCurrent(
    String uid,
    Map<String, dynamic> decoded,
    String forDate,
  ) async {
    final batch = _firestore.batch();
    final base = _firestore.collection('users').doc(uid).collection('ai_current');

    // ai_current/meal
    final mealData = NutritionMealPlanAi.fromUnifiedJson(decoded)
        .toFirestore(forDate: forDate);
    batch.set(base.doc('meal'), mealData, SetOptions(merge: true));

    // ai_current/allenamenti
    final allenamentiData = AiCurrentAllenamentiModel.fromUnifiedJson(decoded, forDate)
        .toFirestore();
    batch.set(base.doc('allenamenti'), allenamentiData, SetOptions(merge: true));

    // ai_current/home_longevity_plan
    final homeData = HomeLongevityPlanDay.fromUnifiedJson(decoded, forDate)
        .toFirestoreMap();
    batch.set(base.doc('home_longevity_plan'), homeData, SetOptions(merge: true));

    await batch.commit();

    // Aggiorna diario (operazione separata: legge prima il testo esistente)
    final diaryUpdate = decoded['diary_update'];
    if (diaryUpdate is Map<String, dynamic>) {
      await saveLongevityDiaryUpdate(uid, forDate, diaryUpdate);
    }
  }


  Future<UserProfile?> _getUserProfile(String uid) async {
    final doc = await _firestore
        .collection('users')
        .doc(uid)
        .collection('profile')
        .doc('profile')
        .get();
    if (!doc.exists || doc.data() == null) return null;
    try {
      return UserProfile.fromJson(doc.data()!);
    } catch (_) {
      return null;
    }
  }

  /// Ultimi 7 giorni: `daily_logs` come indice, `activities` per gli allenamenti e `daily_health` per i biometrici.
  List<DayDetail> _buildDetailedLast7Days(
    DateTime end, {
    required List<DailyLogModel> dailyLogs,
    required Map<String, List<Map<String, dynamic>>> activitiesByDate,
    required Map<String, Map<String, dynamic>> dailyHealthByDate,
  }) {
    final logsByDate = {for (final log in dailyLogs) log.date: log};
    final list = <DayDetail>[];
    for (var d = 0; d < 7; d++) {
      final date = end.subtract(Duration(days: d));
      final dateStr = date.toIso8601String().split('T')[0];
      list.add(
        DayDetail(
          date: dateStr,
          log: logsByDate[dateStr],
          activities: activitiesByDate[dateStr] ?? const [],
          health: dailyHealthByDate[dateStr],
        ),
      );
    }
    return list;
  }

  /// Medie settimanali per i restanti giorni dei 2 mesi (copre 2 mesi totali).
  List<WeeklySummary> _buildWeeklyAggregatesTwoMonths({
    required List<DailyLogModel> dailyLogs,
    required Map<String, List<Map<String, dynamic>>> activitiesByDate,
    required List<Map<String, dynamic>> dailyHealth,
  }) {
    final byWeek = <String, _WeekAccumulator>{};
    for (final log in dailyLogs) {
      final weekKey = _weekKey(DateTime.parse(log.date));
      byWeek.putIfAbsent(weekKey, () => _WeekAccumulator());
      byWeek[weekKey]!.addNutrition(log);
    }
    for (final entry in activitiesByDate.entries) {
      final weekKey = _weekKey(DateTime.parse(entry.key));
      byWeek.putIfAbsent(weekKey, () => _WeekAccumulator());
      byWeek[weekKey]!.addActivities(entry.value);
    }
    for (final h in dailyHealth) {
      final date = h['date'] as String?;
      if (date == null) continue;
      final weekKey = _weekKey(DateTime.parse(date));
      byWeek.putIfAbsent(weekKey, () => _WeekAccumulator());
      byWeek[weekKey]!.addHealth(h);
    }

    final weeks = byWeek.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    return weeks.map((e) => e.value.toSummary(e.key)).toList();
  }

  static String _weekKey(DateTime d) {
    final monday = d.subtract(Duration(days: d.weekday - 1));
    return monday.toIso8601String().split('T')[0];
  }

  Future<List<DailyLogModel>> _getDailyLogsRange(
    String uid,
    String startStr,
    String endStr,
  ) async {
    final snapshot = await _firestore
        .collection('users')
        .doc(uid)
        .collection('daily_logs')
        .where(FieldPath.documentId, isGreaterThanOrEqualTo: startStr)
        .where(FieldPath.documentId, isLessThanOrEqualTo: endStr)
        .get();
    return snapshot.docs.map((d) {
      final data = d.data();
      return DailyLogModel.fromJson({
        ...data,
        'date': d.id,
        'goal_today_ia': data['goal_today_ia'] ?? data['goal_today'] ?? '',
        'timestamp': data['timestamp'] ?? Timestamp.now(),
      });
    }).toList();
  }

  Future<Map<String, List<Map<String, dynamic>>>> _getActivitiesRange(
    String uid,
    String startStr,
    String endStr,
  ) async {
    final snapshot = await _firestore
        .collection('users')
        .doc(uid)
        .collection('activities')
        .where('dateKey', isGreaterThanOrEqualTo: startStr)
        .where('dateKey', isLessThanOrEqualTo: endStr)
        .get();
    final byDate = <String, List<Map<String, dynamic>>>{};
    for (final doc in snapshot.docs) {
      final data = doc.data();
      final dateKey = data['dateKey']?.toString();
      if (dateKey == null || dateKey.isEmpty) continue;
      byDate.putIfAbsent(dateKey, () => []).add({'id': doc.id, ...data});
    }
    return byDate;
  }

  Future<List<Map<String, dynamic>>> _getDailyHealthRange(
    String uid,
    String startStr,
    String endStr,
  ) async {
    final snapshot = await _firestore
        .collection('users')
        .doc(uid)
        .collection('daily_health')
        .where(FieldPath.documentId, isGreaterThanOrEqualTo: startStr)
        .where(FieldPath.documentId, isLessThanOrEqualTo: endStr)
        .get();
    return snapshot.docs.map((d) => {...d.data(), 'date': d.id}).toList();
  }

  String _formatUserProfile(UserProfile? p) {
    if (p == null) return 'Profilo non compilato.';
    var base = 'Main goal: ${_mainGoalLabel(p.mainGoal)} | Età: ${p.age} | '
        'Peso: ${p.weightKg} kg | Altezza: ${p.heightCm} cm | '
        'Allenamenti/sett: ${p.trainingDaysPerWeek} | Sonno medio: ${p.avgSleepHours}h';
    final tg = p.trainingGoal;
    if (tg != null &&
        (tg.objectiveKey.isNotEmpty || tg.notes.isNotEmpty)) {
      final parts = <String>[];
      if (tg.objectiveKey.isNotEmpty) parts.add(tg.objectiveKey);
      if (tg.notes.isNotEmpty) parts.add(tg.notes);
      base = '$base | Training: ${parts.join(' — ')}';
    }
    final ng = p.nutritionGoal;
    if (ng == null) return base;
    final extra = StringBuffer();
    if (ng.useSupplements) extra.write(', integratori: sì');
    final notes = ng.extraNotes.trim();
    if (notes.isNotEmpty) {
      extra.write(', note: ');
      extra.write(notes.length > 120 ? '${notes.substring(0, 117)}…' : notes);
    }
    return '$base | Nutrizione: ${ng.nutritionObjective}, '
        '~${ng.calorieTarget.round()} kcal/die, proteine ${ng.proteinGramsPerKg.toStringAsFixed(1)} g/kg, '
        'velocità ${ng.speed}, stile ${ng.style}${extra.toString()}';
  }

  String _mainGoalLabel(String goal) {
    const map = {
      'weight_loss': 'Perdita peso',
      'muscle_gain': 'Aumento massa muscolare',
      'longevity': 'Longevità',
      'strength': 'Forza',
    };
    return map[goal] ?? goal;
  }

  String _formatWeeklySummary(List<WeeklySummary> weeks) {
    if (weeks.isEmpty) return 'Nessun dato.';
    final sb = StringBuffer();
    for (final w in weeks) {
      sb.writeln(
        'Settimana ${w.weekStart}: km_tot=${w.totalDistanceKm.toStringAsFixed(1)}, '
        'workouts=${w.totalWorkouts}, passi_med=${w.avgSteps.round()}, '
        'sonno_med=${w.avgSleepScore?.round() ?? 0}, kcal_med=${w.avgCalories.round()}, '
        'VO2Max=${w.vo2Max?.toStringAsFixed(1) ?? "—"}, FitnessAge=${w.fitnessAge?.toStringAsFixed(0) ?? "—"}',
      );
    }
    return sb.toString();
  }

  DayDetail? _detailForCalendarDate(List<DayDetail> days, String ymd) {
    for (final d in days) {
      if (d.date == ymd) return d;
    }
    return null;
  }

  void _appendActivitiesLines(
    StringBuffer sb,
    Iterable<Map<String, dynamic>> acts,
  ) {
    for (final a in acts) {
      final type =
          a['activityType'] ??
          a['activityTypeKey'] ??
          a['sport_type'] ??
          a['type'] ??
          '?';
      final distKm =
          (a['distanceKm'] as num?)?.toDouble() ??
          (((a['distance'] as num?)?.toDouble() ?? 0) / 1000);
      final elapsedMin =
          (a['elapsedMinutes'] as num?)?.toDouble() ??
          (a['activeMinutes'] as num?)?.toDouble();
      final avgHr = (a['avgHeartrate'] as num?)?.toDouble();
      final kcalAct = (a['calories'] as num?)?.toDouble();
      final src = a['source']?.toString().trim();
      final parts = <String>[];
      if (distKm > 0) parts.add('${distKm.toStringAsFixed(1)} km');
      if (elapsedMin != null && elapsedMin > 0) {
        parts.add('${elapsedMin.round()} min');
      }
      if (avgHr != null && avgHr > 0) {
        parts.add('FC media ${avgHr.round()}');
      }
      if (kcalAct != null && kcalAct > 0) {
        parts.add('${kcalAct.round()} kcal');
      }
      if (src != null && src.isNotEmpty) {
        parts.add('fonte: $src');
      }
      sb.writeln(
        parts.isEmpty ? '  - $type' : '  - $type: ${parts.join(' | ')}',
      );
    }
  }

  void _appendDayHealthSnippet(
    StringBuffer sb,
    Map<String, dynamic>? health,
  ) {
    if (health == null) return;
    final stats = health['stats'] as Map<String, dynamic>?;
    final steps = stats?['totalSteps'] ?? stats?['userSteps'];
    final bb = stats?['bodyBatteryMostRecentValue'];
    final sleep = health['sleep'] as Map<String, dynamic>?;
    final sleepScore = sleep?['sleepScore'] ?? sleep?['overallSleepScore'];
    final maxMetrics = health['max_metrics'] as Map<String, dynamic>?;
    final vo2max =
        maxMetrics?['vo2Max'] ?? maxMetrics?['maxVo2'] ?? stats?['vo2Max'];
    final fitnessAge = health['fitness_age'] as Map<String, dynamic>?;
    final fitnessAgeVal = fitnessAge?['fitnessAge'] ?? fitnessAge?['age'];
    sb.writeln(
      'Passi: $steps | Body Battery: $bb | Sonno: $sleepScore | '
      'VO2Max: ${vo2max ?? "—"} | Fitness Age: ${fitnessAgeVal ?? "—"}',
    );
  }

  void _appendDayDetailBody(StringBuffer sb, DayDetail d) {
    final acts = d.activities;
    if (d.log != null) {
      sb.writeln(
        'Attività: ${acts.length} | Bruciate: ${d.log!.totalBurnedKcalForAggregation.toStringAsFixed(0)} kcal',
      );
      sb.writeln('Nutrizione: ${_formatNut(d.log!.nutritionForAi)}');
    } else {
      if (acts.isEmpty) {
        sb.writeln(
          'Daily_log non presente; nessuna attività Firestore per questo giorno.',
        );
      } else {
        sb.writeln(
          'Daily_log non presente; ${acts.length} attività da Garmin/Strava/Mi Fitness.',
        );
      }
    }
    _appendActivitiesLines(sb, acts);
    _appendDayHealthSnippet(sb, d.health);
  }

  String _formatTodayPinnedActivities(UnifiedDailyContext ctx) {
    final d = _detailForCalendarDate(ctx.detailed7Days, ctx.todayDate) ??
        (ctx.detailed7Days.isNotEmpty ? ctx.detailed7Days.first : null);
    if (d == null) {
      return 'Nessun dato strutturato per ${ctx.todayDate}.';
    }
    final sb = StringBuffer();
    sb.writeln(
      'Usa SEMPRE queste righe come verità per le attività già registrate oggi '
      '(${ctx.todayDate}). Se la lista non è vuota, riconoscile in '
      'done_today_summary e calcola progress_against_goal_0_1 in base a durata/tipo vs obiettivo.',
    );
    _appendDayDetailBody(sb, d);
    return sb.toString().trimRight();
  }

  String _formatExistingAllenamentoBlock(AiCurrentAllenamentiModel? m) {
    if (m == null || !m.hasContent) {
      return 'Nessun obiettivo allenamento già salvato per oggi — è la prima analisi della giornata o non c’è ancora un piano.';
    }
    return '''
OBIETTIVO ALLENAMENTO GIÀ FISSATO PER OGGI (vincolante):
- tipo: ${m.tipo}
- durata_min: ${m.durataMins}
- intensita: ${m.intensita}
- descrizione attuale: ${m.descrizione}

REGOLE: mantieni IDENTICI tipo, durata_min e intensita nella risposta JSON (il sistema li riallinea comunque).
Aggiorna obbligatoriamente progress_against_goal_0_1 (0.0–1.0) e done_today_summary in base alle attività già registrate oggi.
Se servono integrazioni, scrivile nella descrizione come aggiunta (complementare o recupero), senza contraddire l’obiettivo base.
'''.trim();
  }

  String _formatDetailed7Days(List<DayDetail> days) {
    final sb = StringBuffer();
    for (final d in days) {
      sb.writeln('--- ${d.date} ---');
      _appendDayDetailBody(sb, d);
      sb.writeln();
    }
    return sb.toString();
  }

  String _formatNut(Map<String, dynamic> nut) {
    if (nut.isEmpty) return 'nessun dato';
    final cal = nut['total_calories'] ?? nut['total_kcal'];
    final p = nut['protein_g'] ?? nut['total_protein'];
    return '${cal != null ? "${(cal as num).round()} kcal" : ""} P:${p != null ? (p as num).round() : 0}g';
  }

  String _formatNotes(BaselineProfileModel? b) {
    if (b == null) return 'Nessuna nota.';
    return 'goal_ia: ${b.goalIa}\nevolution_notes: ${b.evolutionNotes}';
  }

  Future<DailyLogModel?> _getTodayLog(String uid, String dateStr) async {
    final doc = await _firestore
        .collection('users')
        .doc(uid)
        .collection('daily_logs')
        .doc(dateStr)
        .get();

    if (!doc.exists || doc.data() == null) return null;

    final data = doc.data()!;
    return DailyLogModel.fromJson({
      ...data,
      'date': doc.id,
      'goal_today_ia': data['goal_today_ia'] ?? data['goal_today'] ?? '',
      'timestamp': data['timestamp'] ?? Timestamp.now(),
    });
  }

  Future<Rolling10DaysModel?> _getRolling10Days(String uid) async {
    final doc = await _firestore
        .collection('users')
        .doc(uid)
        .collection('rolling_10days')
        .doc('current')
        .get();

    if (!doc.exists || doc.data() == null) return null;

    return Rolling10DaysModel.fromJson(doc.data()!);
  }

  Future<BaselineProfileModel?> _getBaseline(String uid) async {
    final doc = await _firestore
        .collection('users')
        .doc(uid)
        .collection('profile')
        .doc('baseline')
        .get();

    if (!doc.exists || doc.data() == null) return null;

    return BaselineProfileModel.fromJson({...doc.data()!});
  }
}

/// Contesto unificato per il prompt giornaliero.
/// Combina il ricco contesto storico (2 mesi, 7 giorni, baseline) con i dati
/// più recenti (ieri specifico, rolling 10 giorni) e il diario evolutivo.
class UnifiedDailyContext {
  final UserProfile? userProfile;
  final String yesterdayDate;
  final String todayDate;

  /// Dati di ieri: estratti dall'elemento 0 di [detailed7Days].
  final DailyLogModel? yesterdayLog;
  final List<Map<String, dynamic>> yesterdayActivities;
  final Map<String, dynamic>? yesterdayHealth;

  /// Rolling aggregato 10 giorni.
  final Rolling10DaysModel? rolling;

  /// Diario evoluzione utente (da profile/diary).
  final String longevityDiary;

  /// Profilo baseline annuale (da profile/baseline).
  final BaselineProfileModel? baseline;

  /// Ultimi 7 giorni in dettaglio (attività + biometrici).
  final List<DayDetail> detailed7Days;

  /// Medie settimanali ultimi 2 mesi.
  final List<WeeklySummary> weekly2Months;

  /// Piano `ai_current/allenamenti` già salvato per [todayDate] (se esiste).
  final AiCurrentAllenamentiModel? existingAllenamentiForToday;

  const UnifiedDailyContext({
    this.userProfile,
    required this.yesterdayDate,
    required this.todayDate,
    this.yesterdayLog,
    this.yesterdayActivities = const [],
    this.yesterdayHealth,
    this.rolling,
    this.longevityDiary = '',
    this.baseline,
    this.detailed7Days = const [],
    this.weekly2Months = const [],
    this.existingAllenamentiForToday,
  });
}

/// Contesto completo per prompt Gemini: profilo + 2 mesi + 7 giorni + note + diario longevità.
class GeminiHomeContext {
  final UserProfile? userProfile;
  final List<DayDetail> detailed7Days;
  final List<WeeklySummary> weeklySummary;
  final BaselineProfileModel? baseline;
  /// Diario della Longevità precedente (da ai_insights) per aggiornare lo storico.
  final String longevityDiary;

  const GeminiHomeContext({
    this.userProfile,
    required this.detailed7Days,
    required this.weeklySummary,
    this.baseline,
    this.longevityDiary = '',
  });
}

/// Dettaglio di un singolo giorno (attività + daily_health).
class DayDetail {
  final String date;
  final DailyLogModel? log;
  final List<Map<String, dynamic>> activities;
  final Map<String, dynamic>? health;

  const DayDetail({
    required this.date,
    this.log,
    this.activities = const [],
    this.health,
  });
}

/// Riepilogo settimanale aggregato (medie/ totali per settimana).
class WeeklySummary {
  final String weekStart;
  final double totalDistanceKm;
  final int totalWorkouts;
  final double avgSteps;
  final double? avgSleepScore;
  final double avgCalories;
  final double? vo2Max;
  final double? fitnessAge;

  const WeeklySummary({
    required this.weekStart,
    required this.totalDistanceKm,
    required this.totalWorkouts,
    required this.avgSteps,
    this.avgSleepScore,
    required this.avgCalories,
    this.vo2Max,
    this.fitnessAge,
  });
}

class _WeekAccumulator {
  final distances = <double>[];
  int workouts = 0;
  final steps = <double>[];
  final sleepScores = <double>[];
  final calories = <double>[];
  double? latestVo2Max;
  double? latestFitnessAge;

  void addNutrition(DailyLogModel log) {
    final nut = log.nutritionForAi;
    final cal = nut['total_calories'] ?? nut['total_kcal'];
    if (cal != null) calories.add((cal as num).toDouble());
  }

  void addActivities(List<Map<String, dynamic>> acts) {
    workouts += acts.length;
    for (final a in acts) {
      final distanceKm = (a['distanceKm'] as num?)?.toDouble();
      final legacyDistance = (a['distance'] as num?)?.toDouble();
      final meters = distanceKm != null && distanceKm > 0
          ? distanceKm * 1000
          : legacyDistance != null && legacyDistance > 0
          ? (legacyDistance < 100 ? legacyDistance * 1000 : legacyDistance)
          : null;
      if (meters != null && meters > 0) distances.add(meters);
    }
  }

  void addHealth(Map<String, dynamic> h) {
    final stats = h['stats'] as Map<String, dynamic>?;
    if (stats != null) {
      final s = stats['totalSteps'] ?? stats['userSteps'];
      if (s != null) steps.add((s as num).toDouble());
    }
    final sleep = h['sleep'] as Map<String, dynamic>?;
    if (sleep != null) {
      final score = sleep['sleepScore'] ?? sleep['overallSleepScore'];
      if (score != null) sleepScores.add((score as num).toDouble());
    }
    final maxMetrics = h['max_metrics'] as Map<String, dynamic>?;
    if (maxMetrics != null) {
      final v =
          maxMetrics['vo2Max'] ?? maxMetrics['maxVo2'] ?? stats?['vo2Max'];
      if (v != null) latestVo2Max = (v as num).toDouble();
    }
    final fitnessAge = h['fitness_age'] as Map<String, dynamic>?;
    if (fitnessAge != null) {
      final fa = fitnessAge['fitnessAge'] ?? fitnessAge['age'];
      if (fa != null) latestFitnessAge = (fa as num).toDouble();
    }
  }

  WeeklySummary toSummary(String weekStart) {
    final distKm = distances.isEmpty
        ? 0.0
        : distances.reduce((a, b) => a + b) / 1000;
    final avgSteps = steps.isEmpty
        ? 0.0
        : steps.reduce((a, b) => a + b) / steps.length;
    final avgSleep = sleepScores.isEmpty
        ? null
        : sleepScores.reduce((a, b) => a + b) / sleepScores.length;
    final avgCal = calories.isEmpty
        ? 0.0
        : calories.reduce((a, b) => a + b) / calories.length;
    return WeeklySummary(
      weekStart: weekStart,
      totalDistanceKm: distKm,
      totalWorkouts: workouts,
      avgSteps: avgSteps,
      avgSleepScore: avgSleep,
      avgCalories: avgCal,
      vo2Max: latestVo2Max,
      fitnessAge: latestFitnessAge,
    );
  }
}
