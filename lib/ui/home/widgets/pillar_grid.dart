import 'package:fitai_analyzer/theme/app_theme.dart';
import 'package:fitai_analyzer/ui/widgets/design/design.dart';
import 'package:fitai_analyzer/ui/widgets/nature_icon.dart';
import 'package:flutter/material.dart';

/// Griglia AI 2x2 con i 4 quadranti della longevità (Peter Attia).
enum LongevityPillar {
  // Toni natura NaturaVita: distinti tra loro e con buon glow in tema scuro.
  // [asset] = icona SVG line-art (stile foto), sostituisce l'icona Material.
  cuore(
    'Cuore',
    'Zona 2 / VO2 Max',
    Icons.favorite,
    Color(0xFFE5736B), // coral
    NatureIcons.heart,
  ),
  forza(
    'Forza',
    'Resistenza muscolare',
    Icons.fitness_center,
    Color(0xFFC9A227), // amber-gold
    NatureIcons.strength,
  ),
  alimentazione(
    'Alimentazione',
    'Analisi pasti Gemini',
    Icons.restaurant,
    Color(0xFF6FB36F), // leaf green
    NatureIcons.nutrition,
  ),
  recupero(
    'Recupero',
    'HRV e Sonno',
    Icons.bedtime,
    Color(0xFF5FB6C9), // lagoon teal
    NatureIcons.recovery,
  );

  const LongevityPillar(
    this.title,
    this.subtitle,
    this.icon,
    this.color,
    this.asset,
  );

  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;

  /// Asset SVG line-art (stile NaturaVita).
  final String asset;
}

/// Griglia 2x2 delle card pilastro.
class PillarGrid extends StatelessWidget {
  const PillarGrid({
    super.key,
    this.isLoading = false,
    this.pillarContents,
    this.pillarCompletion = const {},
    this.onGenerateTap,
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
    this.onPillarCompletionAnswer,
  });

  final LongevityPillar pillar;
  final String? content;
  final bool? completion;
  final bool isLoading;
  final VoidCallback? onEmptyTap;
  final Future<void> Function(LongevityPillar pillar, bool completed)?
  onPillarCompletionAnswer;

  bool get _hasContent => content != null && content!.trim().isNotEmpty;

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
          NatureIcon(pillar.asset, color: pillar.color, size: 24, glow: true),
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
      return NatureIcon(
        pillar.asset,
        color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.65),
        size: 24,
      );
    }
    return NatureIcon(pillar.asset, color: pillar.color, size: 24, glow: true);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final iconBox = Container(
      padding: const EdgeInsets.all(8),
      decoration: _iconDecoration(theme),
      child: _iconChild(theme),
    );

    return FitSoftCard(
      padding: const EdgeInsets.all(16),
      onTap: () {
        if (!_hasContent) {
          onEmptyTap?.call();
          return;
        }
        _showCompletionQuestion(context);
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              iconBox,
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      pillar.title.toUpperCase(),
                      style: AppText.sectionTitle(
                        fontSize: 12,
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
    );
  }
}
