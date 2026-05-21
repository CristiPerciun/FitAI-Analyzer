import 'package:flutter/material.dart';

/// Card a tutta larghezza: "+" per scegliere/cambiare widget; "×" per rimuoverlo.
class HomeWidgetAddCard extends StatelessWidget {
  const HomeWidgetAddCard({
    super.key,
    required this.onTap,
    this.onRemove,
    this.hasSelection = false,
  });

  final VoidCallback onTap;
  final VoidCallback? onRemove;
  final bool hasSelection;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        height: 56,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: theme.colorScheme.primary.withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: InkWell(
                onTap: onTap,
                borderRadius: const BorderRadius.horizontal(left: Radius.circular(16)),
                child: Center(
                  child: Icon(
                    hasSelection ? Icons.swap_horiz : Icons.add,
                    color: theme.colorScheme.primary,
                    size: 28,
                    semanticLabel: hasSelection
                        ? 'Cambia widget Home'
                        : 'Aggiungi widget Home',
                  ),
                ),
              ),
            ),
            if (hasSelection && onRemove != null) ...[
              Container(
                width: 1,
                height: 32,
                color: theme.colorScheme.outline.withValues(alpha: 0.25),
              ),
              InkWell(
                onTap: onRemove,
                borderRadius: const BorderRadius.horizontal(right: Radius.circular(16)),
                child: SizedBox(
                  width: 56,
                  height: 56,
                  child: Icon(
                    Icons.close,
                    color: theme.colorScheme.error,
                    size: 24,
                    semanticLabel: 'Rimuovi widget dalla Home',
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
