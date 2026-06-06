/// Domande onboarding condizionate al [UserProfile.mainGoal].
///
/// **Fonte di verità unica** per quali domande specifiche mostrare in base
/// all'obiettivo: usata sia dal wizard di primo avvio (`OnboardingScreen`) sia
/// dalla modifica da Impostazioni (`MainProfileSinglePageFields`), così la
/// visibilità non diverge tra i due flussi.
///
/// Principio: raccogliere SOLO i dati pertinenti all'obiettivo scelto, per dare
/// all'AI un contesto più chiaro senza domande inutili.
library;

import 'package:fitai_analyzer/models/user_profile.dart';

/// Livello di attività quotidiana (NEAT) — mostrato per **tutti** gli obiettivi.
/// Le chiavi combaciano con `NutritionCalculatorService.activityMultiplierForLevel`.
const dailyActivityOptions = <(String key, String label)>[
  ('sedentario', 'Sedentario (lavoro da seduto, poco movimento)'),
  ('leggero', 'Leggero (in piedi / camminate)'),
  ('moderato', 'Moderato (attivo durante il giorno)'),
  ('attivo', 'Attivo (lavoro fisico / molto movimento)'),
  ('molto_attivo', 'Molto attivo (lavoro fisico intenso)'),
];

/// Esperienza di allenamento — per `muscle_gain` / `strength`.
const trainingExperienceOptions = <(String key, String label)>[
  ('principiante', 'Principiante (meno di 1 anno)'),
  ('intermedio', 'Intermedio (1–3 anni)'),
  ('avanzato', 'Avanzato (oltre 3 anni)'),
];

/// Focus dell'allenamento — per `muscle_gain` / `strength`.
const trainingFocusOptions = <(String key, String label)>[
  ('ipertrofia_generale', 'Ipertrofia generale (tutto il corpo)'),
  ('forza_massimale', 'Forza massimale (grandi alzate)'),
  ('parte_superiore', 'Enfasi parte superiore'),
  ('parte_inferiore', 'Enfasi parte inferiore / gambe'),
  ('atletismo', 'Atletismo / potenza'),
];

/// Priorità di longevità (framework Attia) — per `longevity`, selezione multipla.
const longevityPriorityOptions = <(String key, String label)>[
  ('zone2', 'Zone 2 (base aerobica)'),
  ('vo2max', 'VO2max (picco aerobico)'),
  ('forza', 'Forza muscolare'),
  ('stabilita', 'Stabilità / equilibrio'),
  ('mobilita', 'Mobilità articolare'),
];

/// Quali domande specifiche per obiettivo mostrare per un dato [mainGoal].
class GoalQuestionVisibility {
  /// Peso obiettivo (kg) — `weight_loss`.
  final bool showTargetWeight;

  /// Esperienza + focus allenamento — `muscle_gain` / `strength`.
  final bool showTrainingExperience;

  /// Priorità longevità + target Zone 2 — `longevity`.
  final bool showLongevityPriorities;

  const GoalQuestionVisibility({
    this.showTargetWeight = false,
    this.showTrainingExperience = false,
    this.showLongevityPriorities = false,
  });
}

/// Visibilità delle domande specifiche in base al [mainGoal] selezionato.
/// Il livello di attività quotidiana è invece sempre mostrato (universale).
GoalQuestionVisibility visibilityForGoal(String? mainGoal) {
  switch (mainGoal) {
    case 'weight_loss':
      return const GoalQuestionVisibility(showTargetWeight: true);
    case 'muscle_gain':
    case 'strength':
      return const GoalQuestionVisibility(showTrainingExperience: true);
    case 'longevity':
      return const GoalQuestionVisibility(showLongevityPriorities: true);
    default:
      return const GoalQuestionVisibility();
  }
}

/// Etichetta leggibile per una chiave di opzione (cerca tra le liste note).
String labelForOptionKey(String key) {
  for (final list in const [
    dailyActivityOptions,
    trainingExperienceOptions,
    trainingFocusOptions,
    longevityPriorityOptions,
  ]) {
    for (final e in list) {
      if (e.$1 == key) return e.$2;
    }
  }
  return key;
}

/// Riga di contesto per i prompt AI con i SOLI dati specifici per obiettivo
/// effettivamente presenti nel profilo. Stringa vuota se non c'è nulla.
String goalSpecificContextLine(UserProfile p) {
  final parts = <String>[];
  final activity = p.dailyActivityLevel;
  if (activity != null && activity.trim().isNotEmpty) {
    parts.add('attività quotidiana: ${labelForOptionKey(activity)}');
  }
  if (p.targetWeightKg != null) {
    parts.add('peso obiettivo: ${p.targetWeightKg} kg');
  }
  final exp = p.trainingExperience;
  if (exp != null && exp.trim().isNotEmpty) {
    parts.add('esperienza allenamento: ${labelForOptionKey(exp)}');
  }
  final focus = p.trainingFocus;
  if (focus != null && focus.trim().isNotEmpty) {
    parts.add('focus allenamento: ${labelForOptionKey(focus)}');
  }
  if (p.zone2MinutesTarget != null) {
    parts.add('target Zone 2: ${p.zone2MinutesTarget} min/sett');
  }
  if (p.longevityPriorities.isNotEmpty) {
    parts.add(
      'priorità longevità: ${p.longevityPriorities.map(labelForOptionKey).join(', ')}',
    );
  }
  return parts.join(' | ');
}
