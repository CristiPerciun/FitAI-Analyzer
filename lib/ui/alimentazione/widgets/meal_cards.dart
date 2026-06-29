import 'dart:convert';

import 'package:fitai_analyzer/models/meal_model.dart';
import 'package:fitai_analyzer/providers/pending_meal_analysis_provider.dart';
import 'package:fitai_analyzer/providers/providers.dart';
import 'package:fitai_analyzer/theme/app_card_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Card pasto per una data+tipo: osserva i pasti del giorno e quelli in analisi.
class MealCardForDate extends ConsumerWidget {
  const MealCardForDate({
    super.key,
    required this.dateStr,
    required this.label,
    required this.onTap,
    required this.onMealEdit,
    required this.onRetryPending,
    required this.onDismissPending,
  });

  final String dateStr;
  final String label;
  final VoidCallback onTap;
  final void Function(MealModel meal) onMealEdit;
  final void Function(PendingMealAnalysis pending) onRetryPending;
  final void Function(String pendingId) onDismissPending;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mealsAsync = ref.watch(mealsForDateByTypeProvider(dateStr));
    final meals = mealsAsync.valueOrNull?[label] ?? [];
    final pendingMeals = ref
        .watch(pendingMealAnalysisProvider)
        .where((p) => p.dateStr == dateStr && p.mealTypeLabel == label)
        .toList();
    return _MealCard(
      label: label,
      meals: meals,
      pendingMeals: pendingMeals,
      onTap: onTap,
      onMealEdit: onMealEdit,
      onRetryPending: onRetryPending,
      onDismissPending: onDismissPending,
    );
  }
}

class _MealCard extends StatelessWidget {
  const _MealCard({
    required this.label,
    required this.meals,
    required this.pendingMeals,
    required this.onTap,
    required this.onMealEdit,
    required this.onRetryPending,
    required this.onDismissPending,
  });

  final String label;
  final List<MealModel> meals;
  final List<PendingMealAnalysis> pendingMeals;
  final VoidCallback onTap;
  final void Function(MealModel meal) onMealEdit;
  final void Function(PendingMealAnalysis pending) onRetryPending;
  final void Function(String pendingId) onDismissPending;

  @override
  Widget build(BuildContext context) {
    final cardTheme = Theme.of(context).extension<AppCardTheme>()!;

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: cardTheme.heroDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(24),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        label,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: cardTheme.contentColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: cardTheme.contentColor.withValues(alpha: 0.3),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.add,
                        color: cardTheme.contentColor,
                        size: 24,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (pendingMeals.isNotEmpty || meals.isNotEmpty) ...[
            Divider(
              height: 1,
              color: cardTheme.contentColor.withValues(alpha: 0.4),
            ),
            ...pendingMeals.map(
              (p) => _PendingMealTile(
                pending: p,
                cardTheme: cardTheme,
                onRetry: () => onRetryPending(p),
                onDismissError: p.errorMessage != null
                    ? () => onDismissPending(p.id)
                    : null,
              ),
            ),
            ...meals.map(
              (meal) => _MealTile(meal: meal, onTap: () => onMealEdit(meal)),
            ),
          ],
        ],
      ),
    );
  }
}

class _MealTile extends StatelessWidget {
  const _MealTile({required this.meal, required this.onTap});

  final MealModel meal;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cardTheme = Theme.of(context).extension<AppCardTheme>()!;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Row(
            children: [
              _MealThumbOrPlaceholder(meal: meal, cardTheme: cardTheme),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  meal.displayTitle,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: cardTheme.contentColor,
                  ),
                ),
              ),
              Text(
                '${meal.calories} kcal',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: cardTheme.contentColor,
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.chevron_right,
                color: cardTheme.contentColorMuted,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MealThumbOrPlaceholder extends StatelessWidget {
  const _MealThumbOrPlaceholder({required this.meal, required this.cardTheme});

  final MealModel meal;
  final AppCardTheme cardTheme;

  static const double _size = 48;

  @override
  Widget build(BuildContext context) {
    final thumb = meal.mealThumbBase64;
    if (thumb != null && thumb.isNotEmpty) {
      try {
        final raw = base64Decode(thumb);
        return ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Image.memory(
            raw,
            width: _size,
            height: _size,
            fit: BoxFit.cover,
            gaplessPlayback: true,
          ),
        );
      } catch (_) {}
    }
    return Container(
      width: _size,
      height: _size,
      decoration: BoxDecoration(
        color: cardTheme.contentColor.withValues(alpha: 0.22),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(Icons.restaurant, color: cardTheme.contentColor, size: 24),
    );
  }
}

class _PendingMealTile extends StatelessWidget {
  const _PendingMealTile({
    required this.pending,
    required this.cardTheme,
    required this.onRetry,
    this.onDismissError,
  });

  final PendingMealAnalysis pending;
  final AppCardTheme cardTheme;
  final VoidCallback onRetry;
  final VoidCallback? onDismissError;

  static const double _thumbSize = 48;

  @override
  Widget build(BuildContext context) {
    final isManual = pending.isManualEntry;
    final subtitle = pending.analyzing
        ? 'Analisi IA in corso…'
        : (pending.errorMessage ?? 'Errore');
    final title = isManual
        ? 'Descrizione inviata all’IA'
        : 'Foto inviata all’IA';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: _thumbSize,
            height: _thumbSize,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (isManual)
                    Container(
                      color: cardTheme.contentColor.withValues(alpha: 0.22),
                      child: Icon(
                        Icons.edit_note,
                        color: cardTheme.contentColor,
                        size: 28,
                      ),
                    )
                  else
                    Image.memory(
                      pending.imageBytes!,
                      fit: BoxFit.cover,
                      gaplessPlayback: true,
                    ),
                  if (pending.analyzing)
                    Center(
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: cardTheme.contentColor.withValues(alpha: 0.92),
                          shape: BoxShape.circle,
                        ),
                        child: SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Theme.of(context).colorScheme.surface,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: cardTheme.contentColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (isManual && pending.manualDescription != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    pending.manualDescription!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: cardTheme.contentColorMuted,
                    ),
                  ),
                ],
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: pending.errorMessage != null
                        ? Theme.of(context).colorScheme.error
                        : cardTheme.contentColorMuted,
                  ),
                ),
              ],
            ),
          ),
          if (!pending.analyzing && pending.errorMessage != null) ...[
            IconButton(
              onPressed: onRetry,
              icon: Icon(Icons.refresh, color: cardTheme.contentColor),
              tooltip: 'Riprova',
            ),
            if (onDismissError != null)
              IconButton(
                onPressed: onDismissError,
                icon: Icon(Icons.close, color: cardTheme.contentColorMuted),
                tooltip: 'Chiudi',
              ),
          ],
        ],
      ),
    );
  }
}
