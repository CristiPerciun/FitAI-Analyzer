import 'package:fitai_analyzer/theme/app_theme.dart';
import 'package:flutter/material.dart';

/// Card orizzontale "Weekly Sprint": obiettivo settimanale (7 giorni) generato dall'AI.
/// Es: "Mantieni l'HRV sopra i 60ms", "150 min Zone 2 questa settimana".
class WeeklySprintCard extends StatelessWidget {
  const WeeklySprintCard({
    super.key,
    this.content,
    this.isLoading = false,
    this.onGenerateTap,
  });

  /// Testo obiettivo settimanale (da Gemini). Null = vuoto.
  final String? content;

  /// True se Gemini sta caricando.
  final bool isLoading;

  /// Callback quando l'utente chiede di generare (card vuota).
  final VoidCallback? onGenerateTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasContent = content != null && content!.trim().isNotEmpty;

    return Material(
      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: hasContent ? null : onGenerateTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: theme.colorScheme.primary.withValues(alpha: 0.3),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.date_range,
                  color: theme.colorScheme.primary,
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Weekly Sprint',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    if (isLoading)
                      Row(
                        children: [
                          SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Generazione obiettivo...',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      )
                    else if (hasContent)
                      Text(
                        content!,
                        style: theme.textTheme.bodyMedium,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      )
                    else
                      Text(
                        'Tocca per generare obiettivo settimanale',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: AppColors.hintMedium,
                          fontStyle: FontStyle.italic,
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
