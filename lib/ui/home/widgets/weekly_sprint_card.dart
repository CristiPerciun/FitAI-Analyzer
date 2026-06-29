import 'package:fitai_analyzer/ui/widgets/design/design.dart';
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

    return FitSoftCard(
      onTap: hasContent ? null : onGenerateTap,
      child: Row(
        children: [
          const FitIconBadge(icon: Icons.date_range),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Weekly Sprint',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurface,
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
                      color: theme.colorScheme.onSurfaceVariant,
                      fontStyle: FontStyle.italic,
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
