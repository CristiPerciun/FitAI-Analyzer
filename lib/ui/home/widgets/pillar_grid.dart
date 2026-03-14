import 'package:fitai_analyzer/theme/app_theme.dart';
import 'package:flutter/material.dart';

/// Griglia AI 2x2 con i 4 pilastri della longevità (Peter Attia).
/// Le card sono vuote/caricamento finché Gemini non risponde.
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
    this.onGenerateTap,
  });

  /// True se Gemini sta caricando gli obiettivi.
  final bool isLoading;

  /// Contenuti per ogni pilastro (da risposta Gemini). Null = vuoto.
  final Map<LongevityPillar, String>? pillarContents;

  /// Callback quando l'utente chiede di generare obiettivi.
  final VoidCallback? onGenerateTap;

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
          isLoading: isLoading,
          onTap: onGenerateTap,
        );
      }).toList(),
    );
  }
}

class _PillarCard extends StatelessWidget {
  const _PillarCard({
    required this.pillar,
    this.content,
    required this.isLoading,
    this.onTap,
  });

  final LongevityPillar pillar;
  final String? content;
  final bool isLoading;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasContent = content != null && content!.trim().isNotEmpty;

    return Material(
      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: hasContent ? null : onTap,
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
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: pillar.color.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(pillar.icon, color: pillar.color, size: 24),
                  ),
                  const SizedBox(width: 12),
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
              else if (hasContent)
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
                    color: AppColors.hintMedium,
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
