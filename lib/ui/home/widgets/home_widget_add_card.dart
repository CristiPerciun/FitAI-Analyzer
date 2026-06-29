import 'package:fitai_analyzer/ui/home/widgets/home_action_card.dart';
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

    Widget? trailing;
    if (hasSelection && onRemove != null) {
      trailing = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 1,
            height: 32,
            color: theme.colorScheme.outline.withValues(alpha: 0.25),
          ),
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onRemove,
              borderRadius: const BorderRadius.horizontal(
                right: Radius.circular(HomeActionCard.borderRadius),
              ),
              child: SizedBox(
                width: 56,
                height: HomeActionCard.height,
                child: Icon(
                  Icons.close,
                  color: theme.colorScheme.error,
                  size: 24,
                  semanticLabel: 'Rimuovi widget dalla Home',
                ),
              ),
            ),
          ),
        ],
      );
    }

    return HomeActionCard(
      onTap: onTap,
      icon: hasSelection ? Icons.swap_horiz : Icons.add,
      semanticLabel: hasSelection
          ? 'Cambia widget Home'
          : 'Aggiungi widget Home',
      trailing: trailing,
    );
  }
}
