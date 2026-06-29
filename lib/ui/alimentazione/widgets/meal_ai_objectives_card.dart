import 'package:fitai_analyzer/providers/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Obiettivi AI per un singolo pasto (colazione/pranzo/cena) dal piano corrente.
class MealAiObjectivesCard extends ConsumerWidget {
  const MealAiObjectivesCard({super.key, required this.pastoKey});

  final String pastoKey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plan = ref.watch(nutritionMealPlanAiStreamProvider).valueOrNull;
    if (plan == null || !plan.hasAnyObjective) return const SizedBox.shrink();

    // Per gli "spuntini" non c'è un blocco di obiettivi dedicato nel piano AI
    // (il piano copre colazione/pranzo/cena). Manteniamo la card vuota.
    final List<String> items = switch (pastoKey) {
      'colazione' => plan.obiettiviColazione,
      'pranzo' => plan.obiettiviPranzo,
      'cena' => plan.obiettiviCena,
      _ => const <String>[],
    };

    if (items.isEmpty) return const SizedBox.shrink();

    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Material(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.flag_outlined, size: 18, color: cs.primary),
                  const SizedBox(width: 8),
                  Text(
                    'Obiettivi per questo pasto',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              for (final t in items)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
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
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
