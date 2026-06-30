import 'package:fitai_analyzer/models/nutrition_meal_plan_ai.dart';
import 'package:fitai_analyzer/providers/auth_notifier.dart';
import 'package:fitai_analyzer/providers/data_sync_notifier.dart';
import 'package:fitai_analyzer/providers/providers.dart';
import 'package:fitai_analyzer/theme/app_theme.dart';
import 'package:fitai_analyzer/ui/widgets/design/design.dart';
import 'package:fitai_analyzer/ui/widgets/nature_icon.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Primo tab Alimentazione: obiettivi giornalieri da `ai_current/meal` (prompt unificato Home).
class AlimentazioneObjectivesTab extends ConsumerWidget {
  const AlimentazioneObjectivesTab({super.key});

  // Accenti per pasto (mattina calda → giorno verde → sera viola).
  static const Color _cColazione = Color(0xFFE0A23E); // honey/amber
  static const Color _cPranzo = Color(0xFF6FB36F); // leaf green
  static const Color _cCena = Color(0xFF8E7CC9); // soft violet

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final todayStr = DateTime.now().toIso8601String().split('T')[0];
    final planAsync = ref.watch(nutritionMealPlanAiStreamProvider);
    final plan = planAsync.valueOrNull;
    final uid = ref.watch(authNotifierProvider).user?.uid;
    final hasMeals = plan != null && plan.hasAnyObjective;

    return RefreshIndicator(
      onRefresh: () =>
          refreshGarminSync(ref, uid, trigger: 'alimentazione_pull_to_refresh'),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          Text(
            formatDateForDisplay(todayStr),
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Nutrizione e obiettivi della giornata',
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          _DailyMacroObjectiveCard(plan: plan),
          const SizedBox(height: 20),
          Text(
            'OBIETTIVI PER PASTO',
            style: AppText.sectionTitle(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          if (!hasMeals)
            FitSoftCard(
              child: Row(
                children: [
                  NatureIconBadge(
                    NatureIcons.lunch,
                    tint: theme.colorScheme.onSurfaceVariant,
                    boxSize: 48,
                    iconSize: 28,
                    glow: false,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      'Nessun obiettivo pasto da AI. Premi "Analisi" in Home per generarlo.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            )
          else ...[
            _MealObjectiveCard(
              title: 'Colazione',
              asset: NatureIcons.breakfast,
              tint: _cColazione,
              items: plan.obiettiviColazione,
            ),
            _MealObjectiveCard(
              title: 'Pranzo',
              asset: NatureIcons.lunch,
              tint: _cPranzo,
              items: plan.obiettiviPranzo,
            ),
            _MealObjectiveCard(
              title: 'Cena',
              asset: NatureIcons.dinner,
              tint: _cCena,
              items: plan.obiettiviCena,
            ),
          ],
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.info_outline,
                size: 14,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Obiettivi generati tramite Analisi nella Home',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

String _macroBodyLine(Map<String, dynamic> m) {
  num? n(String a, String b) {
    final v = m[a] ?? m[b];
    if (v is num) return v;
    return num.tryParse(v?.toString() ?? '');
  }

  final p = n('proteine_g', 'protein_g');
  final c = n('carboidrati_g', 'carbs_g');
  final f = n('grassi_g', 'fat_g');
  final k = n('kcal', 'calories');
  final parts = <String>[];
  if (p != null) parts.add('P: ${p.round()} g');
  if (c != null) parts.add('C: ${c.round()} g');
  if (f != null) parts.add('G: ${f.round()} g');
  if (k != null) parts.add('${k.round()} kcal');
  return parts.join(' · ');
}

class _DailyMacroObjectiveCard extends StatelessWidget {
  const _DailyMacroObjectiveCard({this.plan});

  final NutritionMealPlanAi? plan;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const accent = Color(0xFF6FB36F); // leaf green (pilastro alimentazione)
    final macro = plan?.macroGiornalieri ?? const <String, dynamic>{};
    final macroLine = macro.isEmpty ? '' : _macroBodyLine(macro);
    final hasMacro = macroLine.isNotEmpty;
    final note = plan?.noteLongevita.trim() ?? '';
    final hasNote = note.isNotEmpty;
    final score = plan?.aderenzaScore;
    final hasExtras = hasNote || score != null;
    final hasContent = hasMacro || hasExtras;

    return FitHeroCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              NatureIconBadge(
                NatureIcons.nutrition,
                tint: accent,
                boxSize: 46,
                iconSize: 28,
                radius: 14,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'TARGET NUTRIZIONALI',
                      style: AppText.sectionTitle(
                        fontSize: 11,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    Text(
                      'Macro della giornata',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (!hasContent)
            Text(
              'Nessun target da AI per oggi. Premi "Analisi" in Home per generarlo.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            )
          else ...[
            if (hasMacro)
              Text(
                macroLine,
                style: theme.textTheme.titleMedium?.copyWith(
                  height: 1.4,
                  fontWeight: FontWeight.w600,
                ),
              ),
            if (score != null) ...[
              if (hasMacro) const SizedBox(height: 10),
              FitBadgePill(
                label: 'Aderenza stimata: $score/100',
                variant: FitBadgeVariant.solid,
              ),
            ],
            if (hasNote) ...[
              if (hasMacro || score != null) const SizedBox(height: 10),
              Text(
                note,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  height: 1.35,
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

/// Card dedicata a un pasto con illustrazione hand-drawn e i suoi obiettivi.
class _MealObjectiveCard extends StatelessWidget {
  const _MealObjectiveCard({
    required this.title,
    required this.asset,
    required this.tint,
    required this.items,
  });

  final String title;
  final String asset;
  final Color tint;
  final List<String> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: FitSoftCard(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            NatureIconBadge(asset, tint: tint, boxSize: 52, iconSize: 30),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 8),
                  for (final t in items)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(top: 6, right: 8),
                            child: Container(
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(
                                color: tint,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                          Expanded(
                            child: Text(
                              t,
                              style: theme.textTheme.bodySmall?.copyWith(
                                height: 1.35,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
