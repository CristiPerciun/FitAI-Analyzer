import 'package:flutter/material.dart';

/// Card azione Home: sfondo soft, bordo primary, altezza fissa (tema chiaro/scuro).
class HomeActionCard extends StatelessWidget {
  const HomeActionCard({
    super.key,
    required this.onTap,
    this.icon = Icons.add,
    this.label,
    this.semanticLabel,
    this.trailing,
  });

  final VoidCallback onTap;
  final IconData icon;
  final String? label;
  final String? semanticLabel;
  /// Widget opzionale a destra (es. pulsante rimuovi widget).
  final Widget? trailing;

  static const double height = 56;
  static const double borderRadius = 16;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;

    return Material(
      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
      borderRadius: BorderRadius.circular(borderRadius),
      child: Container(
        height: height,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(borderRadius),
          border: Border.all(color: primary.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Expanded(
              child: InkWell(
                onTap: onTap,
                borderRadius: BorderRadius.horizontal(
                  left: const Radius.circular(borderRadius),
                  right: Radius.circular(trailing != null ? 0 : borderRadius),
                ),
                child: Semantics(
                  button: true,
                  label: semanticLabel ?? label,
                  child: Center(
                    child: label == null
                        ? Icon(icon, color: primary, size: 28)
                        : Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(icon, color: primary, size: 28),
                              const SizedBox(width: 10),
                              Text(
                                label!,
                                style: theme.textTheme.titleSmall?.copyWith(
                                  color: primary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
              ),
            ),
            if (trailing != null) trailing!,
          ],
        ),
      ),
    );
  }
}
