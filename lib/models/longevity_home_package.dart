import 'package:intl/intl.dart';

import 'baseline_profile_model.dart';
import 'daily_log_model.dart';
import 'rolling_10days_model.dart';

/// Pacchetto informativo unificato per popolare la Home con dati AI.
/// Aggrega Livello 1 (oggi), Livello 2 (rolling 10 giorni), Livello 3 (baseline annuale)
/// sia per alimentazione che per attività fisica.
class LongevityHomePackage {
  /// Livello 1: dettaglio giornaliero di oggi (daily_logs/{date}).
  final DailyLogModel? today;

  /// Livello 2: trend ultimi 10 giorni (rolling_10days/current).
  /// Contiene macro_averages, activities_summary, zone2, VO2.
  final Rolling10DaysModel? rolling;

  /// Livello 3: profilo baseline annuale (baseline_profile/main).
  /// Contiene annual_stats, monthly_trends, key_metrics_attia, ai_ready_summary.
  final BaselineProfileModel? baseline;

  const LongevityHomePackage({
    this.today,
    this.rolling,
    this.baseline,
  });

  static final _dateFormat = DateFormat('d MMM yyyy', 'it');

  /// Costruisce il prompt completo da inviare all'AI per generare contenuti Home.
  /// Include tutti i dati: Livello 1 (oggi), Livello 2 (rolling), Livello 3 (baseline completo).
  /// Livello 3: goal_ia, annual_stats, monthly_trends, key_metrics_attia, evolution_notes, ai_ready_summary.
  String buildAiPrompt() {
    final dateFormat = _dateFormat;
    final baselineStr = baseline != null
        ? dateFormat.format(baseline!.lastBaselineUpdate)
        : 'non disponibile';
    final rollingStr = rolling != null
        ? dateFormat.format(rolling!.lastUpdated)
        : 'non disponibile';

    final goalStr = baseline?.goalIa ?? today?.goalTodayIa ?? '';

    // Livello 3 completo: tutti i campi come da strategia Tre Livelli
    final level3Section = _buildLevel3Section();

    final rollingActivity = rolling != null
        ? 'Distanza: ${rolling!.totalDistanceKm.toStringAsFixed(1)} km | '
            'Zone 2: ${rolling!.totalZone2Minutes} min | '
            'VO2 stimato: ${rolling!.estimatedVo2Max.toStringAsFixed(1)}'
        : 'Nessun dato attività ultimi 10 giorni.';

    final rollingNutrition = _formatMacroAverages(rolling?.macroAverages ?? {});

    final todayActivity = today != null
        ? 'Attività: ${today!.activitiesForAggregation.length} | '
            'Calorie bruciate: ${today!.totalBurnedKcalForAggregation.toStringAsFixed(0)} kcal'
        : 'Nessuna attività registrata oggi.';

    final todayNutrition = _formatNutrition(today?.nutritionForAi ?? {});

    return '''
OBIETTIVO GIORNALIERO IA: $goalStr

---
LIVELLO 3 - STORICO ANNUALE / BASELINE (aggiornato $baselineStr)
$level3Section

---
LIVELLO 2 - ULTIMI 10 GIORNI (aggiornato $rollingStr)
ATTIVITÀ FISICA: $rollingActivity
ALIMENTAZIONE (medie): $rollingNutrition

---
LIVELLO 1 - OGGI
ATTIVITÀ: $todayActivity
NUTRIZIONE: $todayNutrition
${today?.weightKg != null ? 'Peso: ${today!.weightKg!.toStringAsFixed(1)} kg' : ''}

---
Riferimenti Peter Attia (Outlive):
- Zone 2: minimo 150-180 min/settimana
- VO2max >45 = ottimo per longevità
- Proteine adeguate + composizione corporea prioritari

Usa questi dati per generare un messaggio di benvenuto personalizzato per la Home: breve, motivante, con 1-2 insight concreti basati sui dati dell'utente. Rispondi in italiano.
''';
  }

  /// Prompt master per il piano di longevità completo.
  /// Usa il pacchetto Livello 1+2+3 per popolare: odierno, settimanale, visione.
  String buildLongevityPlanPrompt() {
    final level3 = _buildLevel3Section();
    final rollingAct = rolling != null
        ? 'Distanza: ${rolling!.totalDistanceKm.toStringAsFixed(1)} km, Zone 2: ${rolling!.totalZone2Minutes} min, VO2: ${rolling!.estimatedVo2Max.toStringAsFixed(1)}'
        : 'Nessun dato';
    final rollingNut = _formatMacroAverages(rolling?.macroAverages ?? {});
    final todayAct = today != null
        ? 'Attività: ${today!.activitiesForAggregation.length}, Bruciate: ${today!.totalBurnedKcalForAggregation.toStringAsFixed(0)} kcal'
        : 'Nessun dato';
    final todayNut = _formatNutrition(today?.nutritionForAi ?? {});

    return '''
$level3

---
LIVELLO 2: $rollingAct | Nutrizione: $rollingNut
LIVELLO 1 OGGI: $todayAct | $todayNut

---
Sei un esperto di longevità (Peter Attia, Outlive). Genera un piano di longevità composto da:

1. 4 micro-obiettivi per OGGI (uno per pilastro: Cuore, Forza, Alimentazione, Recupero)
2. 1 macro-obiettivo SETTIMANALE (obiettivo che dura 7 giorni)
3. 1 consiglio STRATEGICO a lungo termine (basato su trend annuale e metriche Attia)

Rispondi esclusivamente in formato JSON con esattamente questi campi (in italiano):
{
  "cuore": "micro-obiettivo Zona 2/VO2 Max per oggi (max 80 caratteri)",
  "forza": "micro-obiettivo resistenza muscolare per oggi (max 80 caratteri)",
  "alimentazione": "micro-obiettivo nutrizione per oggi (max 80 caratteri)",
  "recupero": "micro-obiettivo recupero/HRV/sonno per oggi (max 80 caratteri)",
  "weekly_sprint": "macro-obiettivo settimanale 7 giorni (max 120 caratteri)",
  "strategic_advice": "consiglio strategico a lungo termine basato su dati (max 200 caratteri)"
}

Rispondi SOLO con il JSON, nessun altro testo.
''';
  }

  /// Costruisce la sezione Livello 3 con tutti i campi: goal_ia, annual_stats,
  /// monthly_trends, key_metrics_attia, evolution_notes, ai_ready_summary.
  String _buildLevel3Section() {
    if (baseline == null) {
      return 'Nessun baseline ancora. Sincronizza Strava e registra pasti per costruire il profilo.';
    }
    final b = baseline!;
    final sb = StringBuffer();
    sb.writeln('goal_ia: ${b.goalIa}');
    sb.writeln();
    sb.writeln('annual_stats: ${_formatMap(b.annualStats)}');
    sb.writeln();
    sb.writeln('key_metrics_attia: ${_formatMap(b.keyMetricsAttia)}');
    sb.writeln();
    sb.writeln('evolution_notes: ${b.evolutionNotes}');
    sb.writeln();
    sb.writeln('monthly_trends:');
    for (final m in b.monthlyTrends) {
      sb.writeln('  Mese ${m['month']}: km=${m['total_km']}, workouts=${m['workouts']}, avg_kcal=${m['avg_kcal']}, avg_protein=${m['avg_protein']}');
    }
    sb.writeln();
    sb.writeln('ai_ready_summary (testo completo 4000+ caratteri):');
    sb.writeln(b.aiReadySummary);
    if (b.references.isNotEmpty) {
      sb.writeln();
      sb.writeln('references: ${b.references.join(', ')}');
    }
    return sb.toString();
  }

  static String _formatMap(Map<String, dynamic> m) {
    if (m.isEmpty) return '{}';
    return m.entries.map((e) => '${e.key}: ${e.value}').join(', ');
  }

  static String _formatNutrition(Map<String, dynamic> nut) {
    if (nut.isEmpty) return 'nessun dato';
    final parts = <String>[];
    final cal = nut['total_calories'] ?? nut['total_kcal'] ?? nut['calories'];
    if (cal != null) parts.add('${(cal as num).round()} kcal');
    final p = nut['protein_g'] ?? nut['total_protein'] ?? nut['protein'];
    if (p != null) parts.add('P: ${(p as num).round()}g');
    final c = nut['carbs_g'] ?? nut['total_carbs'] ?? nut['carbs'];
    if (c != null) parts.add('C: ${(c as num).round()}g');
    final f = nut['fat_g'] ?? nut['total_fat'] ?? nut['fat'];
    if (f != null) parts.add('F: ${(f as num).round()}g');
    final longevity = nut['avg_longevity_score'];
    if (longevity != null) parts.add('Longevità: $longevity/10');
    return parts.isEmpty ? 'dati parziali' : parts.join(' | ');
  }

  static String _formatMacroAverages(Map<String, double> macro) {
    if (macro.isEmpty) return 'nessun dato';
    final parts = <String>[];
    final cal = macro['calories'];
    if (cal != null) parts.add('${cal.round()} kcal/giorno');
    final p = macro['protein_g'];
    if (p != null) parts.add('P: ${p.round()}g');
    final c = macro['carbs_g'];
    if (c != null) parts.add('C: ${c.round()}g');
    final f = macro['fat_g'];
    if (f != null) parts.add('F: ${f.round()}g');
    return parts.isEmpty ? 'dati parziali' : parts.join(' | ');
  }
}
