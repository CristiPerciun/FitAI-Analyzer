import 'package:flutter/material.dart';

/// Griglia AI 2x2 con i 4 quadranti della longevità (Peter Attia).
enum LongevityPillar {
  cuore('Cuore', 'Zona 2 / VO2 Max', Icons.favorite, Color(0xFFE53935)),
  forza('Forza', 'Resistenza muscolare', Icons.fitness_center, Color(0xFF7B1FA2)),
  alimentazione('Alimentazione', 'Analisi pasti Gemini', Icons.restaurant, Color(0xFF388E3C)),
  recupero('Recupero', 'HRV e Sonno', Icons.bedtime, Color(0xFF1976D2));

  const LongevityPillar(this.title, this.subtitle, this.icon, this.color);

  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
}

/// Griglia 2x2 delle card pilastro.
class PillarGrid extends StatelessWidget {
  const PillarGrid({
    super.key,
    this.isLoading = false,
    this.pillarContents,
    this.pillarCompletion = const {},
    this.onGenerateTap,
    this.onPillarContentTap,
    this.onPillarCompletionAnswer,
  });

  /// True se Gemini sta caricando gli obiettivi.
  final bool isLoading;

  /// Contenuti per ogni pilastro (da risposta Gemini). Null = vuoto.
  final Map<LongevityPillar, String>? pillarContents;

  /// null = non registrato; true/false = risposta dialog.
  final Map<LongevityPillar, bool?> pillarCompletion;

  /// Callback quando l'utente chiede di generare obiettivi (card vuota).
  final VoidCallback? onGenerateTap;

  /// Solo Alimentazione: apre aggiungi pasto. [onTap] isolato dal tap card.
  final Map<LongevityPillar, VoidCallback>? onPillarContentTap;

  /// Dopo Sì/No nel dialog (solo se `hasContent`).
  final Future<void> Function(LongevityPillar pillar, bool completed)?
      onPillarCompletionAnswer;

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.1,
      children: LongevityPillar.values.map((p) {
        return _PillarCard(
          pillar: p,
          content: pillarContents?[p],
          completion: pillarCompletion[p],
          isLoading: isLoading,
          onEmptyTap: onGenerateTap,
          onContentTap: onPillarContentTap?[p],
          onPillarCompletionAnswer: onPillarCompletionAnswer,
        );
      }).toList(),
    );
  }
}

class _PillarCard extends StatelessWidget {
  const _PillarCard({
    required this.pillar,
    this.content,
    this.completion,
    required this.isLoading,
    this.onEmptyTap,
    this.onContentTap,
    this.onPillarCompletionAnswer,
  });

  final LongevityPillar pillar;
  final String? content;
  final bool? completion;
  final bool isLoading;
  final VoidCallback? onEmptyTap;
  final VoidCallback? onContentTap;
  final Future<void> Function(LongevityPillar pillar, bool completed)?
      onPillarCompletionAnswer;

  bool get _hasContent => content != null && content!.trim().isNotEmpty;

  bool get _showMealAdd =>
      pillar == LongevityPillar.alimentazione && _hasContent && onContentTap != null;

  Future<void> _showCompletionQuestion(BuildContext context) async {
    final answered = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(pillar.title),
        content: const Text('Hai completato l\'obiettivo?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('No'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Sì'),
          ),
        ],
      ),
    );
    if (answered == null || !context.mounted) return;
    await onPillarCompletionAnswer?.call(pillar, answered);
  }

  Widget _mealAddButton() {
    return GestureDetector(
      onTap: onContentTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: pillar.color.withValues(alpha: 0.18),
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.add, color: pillar.color, size: 18),
        ),
      ),
    );
  }

  BoxDecoration _iconDecoration(ThemeData theme) {
    if (completion == true) {
      return BoxDecoration(
        color: pillar.color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: pillar.color, width: 2),
      );
    }
    if (completion == false) {
      return BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.45),
          width: 1,
        ),
      );
    }
    return BoxDecoration(
      color: pillar.color.withValues(alpha: 0.15),
      borderRadius: BorderRadius.circular(12),
    );
  }

  Widget _iconChild(ThemeData theme) {
    if (completion == true) {
      return Stack(
        clipBehavior: Clip.none,
        children: [
          Icon(pillar.icon, color: pillar.color, size: 24),
          Positioned(
            right: -4,
            bottom: -4,
            child: Icon(
              Icons.check_circle,
              size: 16,
              color: theme.colorScheme.primary,
            ),
          ),
        ],
      );
    }
    if (completion == false) {
      return Icon(
        pillar.icon,
        color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.65),
        size: 24,
      );
    }
    return Icon(pillar.icon, color: pillar.color, size: 24);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final compact = MediaQuery.sizeOf(context).width < 600;

    final iconBox = Container(
      padding: const EdgeInsets.all(8),
      decoration: _iconDecoration(theme),
      child: _iconChild(theme),
    );

    final leading = _showMealAdd && compact
        ? Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              iconBox,
              const SizedBox(height: 8),
              _mealAddButton(),
            ],
          )
        : iconBox;

    return Material(
      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: () {
          if (!_hasContent) {
            onEmptyTap?.call();
            return;
          }
          _showCompletionQuestion(context);
        },
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: pillar.color.withValues(alpha: 0.3),
              width: 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  leading,
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    pillar.title,
                                    style: theme.textTheme.titleSmall?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: pillar.color,
                                    ),
                                  ),
                                  Text(
                                    pillar.subtitle,
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            if (_showMealAdd && !compact) _mealAddButton(),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const Spacer(),
              if (isLoading)
                Row(
                  children: [
                    SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: pillar.color,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Generazione obiettivi...',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                )
              else if (_hasContent)
                Text(
                  content!,
                  style: theme.textTheme.bodySmall,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                )
              else
                Text(
                  'Tocca per generare obiettivi',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontStyle: FontStyle.italic,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
