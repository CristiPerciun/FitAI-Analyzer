import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../models/baseline_profile_model.dart';
import '../models/daily_log_model.dart';
import '../models/rolling_10days_model.dart';
import '../models/user_profile.dart';
import 'nutrition_calculator_service.dart';

final aiPromptServiceProvider = Provider<AiPromptService>(
  (ref) => AiPromptService(),
);

class AiPromptService {
  static final _dateFormat = DateFormat('d MMM yyyy', 'it');

  /// Costruisce il contesto completo per prompt AI (Gemini/Grok).
  /// Un solo fetch → 8-10k token pronti per analisi scientifica personalizzata.
  Future<String> buildFullAIContext(String uid) async {
    final baseline = await _getBaseline(uid);
    final rolling = await _getRolling10Days(uid);
    final today = await _getTodayLog(uid);

    final baselineStr = baseline != null
        ? _dateFormat.format(baseline.lastBaselineUpdate)
        : 'non disponibile';

    final goalStr = baseline?.goalIa ?? today?.goalTodayIa ?? '';

    final baselineSummary =
        baseline?.aiReadySummary ??
        'Nessun baseline ancora. Esegui prima la sincronizzazione Strava.';

    final rollingStr = rolling != null
        ? 'Distanza: ${rolling.totalDistanceKm.toStringAsFixed(1)} km | Zone 2: ${rolling.totalZone2Minutes} min | VO2 stimato: ${rolling.estimatedVo2Max.toStringAsFixed(1)}'
        : 'Nessun dato rolling ultimi 10 giorni.';

    final todayActivities = today?.activityCountForAi ?? 0;
    final todayBurned = today?.totalBurnedKcalForAggregation ?? 0.0;
    final todayNutrition = _formatNutrition(today?.nutritionForAi ?? {});

    final userProfile = await _getUserProfile(uid);
    final nutritionBlock = userProfile != null
        ? '\n\n${_nutritionObjectiveBlock(userProfile)}'
        : '';

    return """
Obiettivo giornaliero IA: $goalStr.

BASELINE ANNUALE (aggiornata $baselineStr):
$baselineSummary

ULTIMI 10 GIORNI (dettagli completi):
$rollingStr

OGGI:
Attività: $todayActivities | Calorie bruciate: ${todayBurned.toStringAsFixed(0)} | Nutrizione Gemini: $todayNutrition
$nutritionBlock

Riferimenti Peter Attia (Outlive) e studi:
- Zone 2 minimo 150-180 min/settimana
- VO2max >45 = ottimo longevità
- Forza + composizione corporea prioritari

Analizza in modo scientifico, personalizzato e approfondito. Dai piano settimanale concreto.
""";
  }

  /// Prompt breve (legacy: testo libero su daily_log `weekly_meal_plan`).
  String buildNutritionPrompt(UserProfile profile) {
    return '''
${_nutritionObjectiveBlock(profile)}

Genera piano settimanale rispettando CREA 2018 + evidenze ISSN/SINS.
''';
  }

  /// Prompt **pagina Alimentazione**: piano settimanale + obiettivi per pasto in JSON.
  /// Indipendente dal prompt Home / longevità.
  String buildNutritionMealPlanPrompt(UserProfile profile) {
    final ng = profile.nutritionGoal;
    if (ng == null) {
      return '{"error":"Obiettivo mangiare non configurato"}';
    }

    final energy = NutritionCalculatorService.computeFromUserProfile(profile);
    final tdee = energy.tdeeKcal;
    final calorieTarget =
        ng.calorieTarget > 0 ? ng.calorieTarget : energy.calorieTarget;

    final mainGoal = profile.mainGoal;
    final mainLower = mainGoal.toLowerCase();
    final proteinGkFallback = (mainLower.contains('muscle') ||
            mainLower.contains('mass') ||
            mainLower.contains('ipertrofia'))
        ? 2.0
        : 1.8;
    final proteinGk = ng.proteinGramsPerKg > 0
        ? ng.proteinGramsPerKg
        : proteinGkFallback;

    final prefs =
        ng.preferences.isEmpty ? 'nessuna' : ng.preferences.join(', ');
    final medsNote = profile.takesMedications &&
            profile.medicationsList.trim().isNotEmpty
        ? profile.medicationsList.trim()
        : 'nessuna segnalazione';
    final healthNote = profile.healthConditions.trim().isEmpty
        ? 'nessuna'
        : profile.healthConditions.trim();

    return '''
Sei un nutrizionista senior specializzato in:
• Longevità (Peter Attia - Outlive)
• Composizione corporea e performance (ISSN, SINS)
• Ipertrofia pratica (Progetto Invictus / evidenza accademica italiana)
• Linee guida CREA 2018 + LARN 2014 (modello mediterraneo italiano)

DATI UTENTE (usa SOLO questi numeri e testi; non inventare misure antropometriche):
- Obiettivo principale app (4 vie): $mainGoal
- Obiettivo nutrizione (Obiettivo Mangiare): ${ng.nutritionObjective}
- Età: ${profile.age} | Sesso: ${profile.gender} | Peso: ${profile.weightKg} kg | Altezza: ${profile.heightCm} cm
- Giorni allenamento/settimana: ${profile.trainingDaysPerWeek} (TDEE stimato: ${tdee.toStringAsFixed(0)} kcal/giorno da fattore attività)
- Farmaci (info utente, non sostituire il medico): $medsNote
- Condizioni di salute segnalate: $healthNote

OBIETTIVO MANGIARE:
• Velocità desiderata: ${ng.speed}
• Pasti al giorno: ${ng.mealsPerDay}
• Timing pre/post allenamento: ${ng.timingImportante ? 'MOLTO IMPORTANTE' : 'normale'}
• Stile preferito: ${ng.style}
• Preferenze / restrizioni alimentari: $prefs
• Integratori da considerare nel piano: ${ng.useSupplements ? 'SÌ (es. proteine, creatina, omega-3 dove appropriato)' : 'NO'}
• Note personali: ${ng.extraNotes.trim().isEmpty ? 'nessuna' : ng.extraNotes.trim()}

CALORIE TARGET (usa questo valore): ${calorieTarget.toStringAsFixed(0)} kcal/giorno
MACRO INDICATIVI APP: carb ${ng.carbsPercentage}% | grassi ${ng.fatPercentage}%
PROTEINE TARGET: ${proteinGk.toStringAsFixed(1)} g/kg corporeo (allinea pasti e porzioni a questo obiettivo)

GENERA UN PIANO ALIMENTARE SETTIMANALE COMPLETO con questi requisiti:
1. 7 giorni con circa ${ng.mealsPerDay} pasti principali + eventuali spuntini coerenti con lo stile ${ng.style}
2. Macro giornalieri coerenti con calorie target e proteine g/kg indicate
3. Ricette italiane semplici, veloci (max ~15 min), economiche, ingredienti comuni
4. Timing preciso dei pasti se timing pre/post allenamento è MOLTO IMPORTANTE
5. Rotazione per evitare noia (non ripetere lo stesso piatto più di 2 volte nella settimana)
6. Score di aderenza 0-100 rispetto a preferenze e restrizioni dichiarate
7. Lista integratori consigliati solo se integratori = SÌ; altrimenti stringa vuota o "non necessario"
8. **Obiettivi operativi per pasto** (2-4 bullet ciascuno, azioni concrete in italiano) sotto forma JSON

Rispondi SOLO con JSON valido. Nessun testo fuori dal JSON. Lingua contenuti: italiano.

Schema obbligatorio (tutti i campi devono esistere):
{
  "piano_settimanale": [ { "giorno": 1, "nome_giorno": "lun", "pasti": [ { "nome": "colazione", "orario": "08:00", "piatto": "...", "kcal": 0, "note": "" } ] } ],
  "macro_giornalieri": { "proteine_g": 0, "carboidrati_g": 0, "grassi_g": 0, "kcal": 0 },
  "obiettivi_per_pasto": {
    "colazione": ["obiettivo 1", "obiettivo 2"],
    "pranzo": ["obiettivo 1", "obiettivo 2"],
    "cena": ["obiettivo 1", "obiettivo 2"]
  },
  "consigli_integratori": "stringa",
  "aderenza_score": 0,
  "note_longevita": "1-2 frasi su allineamento a longevità / composizione"
}
''';
  }

  static String _nutritionObjectiveBlock(UserProfile profile) {
    final ng = profile.nutritionGoal;
    if (ng == null) {
      return 'Obiettivo mangiare: non configurato (completa sub-onboarding Obiettivo Mangiare).';
    }
    return '''
Main goal (4 vie): ${profile.mainGoal}
Obiettivo nutrizione: ${ng.nutritionObjective}
Target calorico giornaliero: ${ng.calorieTarget.round()} kcal
Proteine: ${ng.proteinGramsPerKg.toStringAsFixed(1)} g/kg (Invictus style)
Velocità: ${ng.speed}
Stile preferito: ${ng.style}
Timing pasti importante: ${ng.timingImportante}
Macro indicativi: carb ${ng.carbsPercentage}% | grassi ${ng.fatPercentage}%
Pasti/giorno: ${ng.mealsPerDay}
Preferenze: ${ng.preferences.isEmpty ? '—' : ng.preferences.join(', ')}
Integratori (proteine, creatina, omega-3, ecc.): ${ng.useSupplements ? 'sì, considerali nei piani' : 'no'}
Note personali: ${ng.extraNotes.trim().isEmpty ? '—' : ng.extraNotes.trim()}''';
  }

  Future<UserProfile?> _getUserProfile(String uid) async {
    final doc = await FirebaseFirestore.instance
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

  Future<BaselineProfileModel?> _getBaseline(String uid) async {
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('baseline_profile')
        .doc('main')
        .get();

    if (!doc.exists || doc.data() == null) return null;

    return BaselineProfileModel.fromJson({...doc.data()!});
  }

  Future<Rolling10DaysModel?> _getRolling10Days(String uid) async {
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('rolling_10days')
        .doc('current')
        .get();

    if (!doc.exists || doc.data() == null) return null;

    return Rolling10DaysModel.fromJson(doc.data()!);
  }

  Future<DailyLogModel?> _getTodayLog(String uid) async {
    final todayStr = DateTime.now().toIso8601String().split('T')[0];

    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('daily_logs')
        .doc(todayStr)
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

  String _formatNutrition(Map<String, dynamic> nut) {
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
}
