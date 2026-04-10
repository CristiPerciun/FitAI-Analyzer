import 'package:fitai_analyzer/models/nutrition_meal_plan_ai.dart';
import 'package:fitai_analyzer/providers/auth_notifier.dart';
import 'package:fitai_analyzer/providers/data_sync_notifier.dart';
import 'package:fitai_analyzer/providers/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Primo tab Alimentazione: obiettivi giornalieri da `ai_current/meal` (prompt unificato Home).
class AlimentazioneObjectivesTab extends ConsumerWidget {
  const AlimentazioneObjectivesTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final todayStr = DateTime.now().toIso8601String().split('T')[0];
    final planAsync = ref.watch(nutritionMealPlanAiStreamProvider);
    final plan = planAsync.valueOrNull;
    final uid = ref.watch(authNotifierProvider).user?.uid;

    return RefreshIndicator(
      onRefresh: () => refreshGarminSync(
        ref,
        uid,
        trigger: 'alimentazione_pull_to_refresh',
      ),
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
          const SizedBox(height: 16),
          _MealObjectivesSummaryCard(plan: plan),
          const SizedBox(height: 20),
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
    final macro = plan?.macroGiornalieri ?? const <String, dynamic>{};
    final macroLine = macro.isEmpty ? '' : _macroBodyLine(macro);
    final hasMacro = macroLine.isNotEmpty;
    final note = plan?.noteLongevita.trim() ?? '';
    final hasNote = note.isNotEmpty;
    final score = plan?.aderenzaScore;
    final hasExtras = hasNote || score != null;
    final hasContent = hasMacro || hasExtras;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: theme.colorScheme.primary.withValues(alpha: 0.3),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.pie_chart_outline,
                  color: theme.colorScheme.primary,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Target nutrizionali (oggi)',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
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
                  style: theme.textTheme.bodyMedium?.copyWith(height: 1.4),
                ),
              if (score != null) ...[
                if (hasMacro) const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'Aderenza stimata: $score/100',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: theme.colorScheme.onPrimaryContainer,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
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
      ),
    );
  }
}

class _MealObjectivesSummaryCard extends StatelessWidget {
  const _MealObjectivesSummaryCard({this.plan});

  final NutritionMealPlanAi? plan;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasMeals = plan != null && plan!.hasAnyObjective;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: theme.colorScheme.outline.withValues(alpha: 0.2),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.restaurant_menu_outlined,
                  color: theme.colorScheme.primary,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Obiettivi per pasto',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (!hasMeals)
              Text(
                'Nessun obiettivo pasto da AI. Premi "Analisi" in Home per generarlo.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              )
            else ...[
              _PastoSection(title: 'Colazione', items: plan!.obiettiviColazione),
              _PastoSection(title: 'Pranzo', items: plan!.obiettiviPranzo),
              _PastoSection(title: 'Cena', items: plan!.obiettiviCena),
            ],
          ],
        ),
      ),
    );
  }
}

class _PastoSection extends StatelessWidget {
  const _PastoSection({required this.title, required this.items});

  final String title;
  final List<String> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w600,
              color: cs.primary,
            ),
          ),
          const SizedBox(height: 6),
          for (final t in items)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '• ',
                    style: TextStyle(
                      color: cs.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      t,
                      style: theme.textTheme.bodySmall?.copyWith(height: 1.35),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
