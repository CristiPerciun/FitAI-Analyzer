import 'package:fitai_analyzer/theme/app_spacing.dart';
import 'package:flutter/material.dart';

/// Riga d'intestazione di una card: titolo (+ sottotitolo) a sinistra,
/// azione "View All ›" o trailing personalizzato a destra.
class FitCardHeader extends StatelessWidget {
  const FitCardHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.actionLabel,
    this.onAction,
    this.trailing,
    this.onHeroSurface = false,
  });

  final String title;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;
  final Widget? trailing;
  final bool onHeroSurface;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final titleColor = onHeroSurface ? cs.onPrimary : cs.onSurface;
    final mutedColor = onHeroSurface
        ? cs.onPrimary.withValues(alpha: 0.85)
        : cs.onSurfaceVariant;
    final actionColor = onHeroSurface ? cs.onPrimary : cs.primary;

    Widget? trailingWidget = trailing;
    if (trailingWidget == null && actionLabel != null) {
      trailingWidget = TextButton(
        onPressed: onAction,
        style: TextButton.styleFrom(
          visualDensity: VisualDensity.compact,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.s,
            vertical: AppSpacing.xs,
          ),
          foregroundColor: actionColor,
          textStyle: theme.textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(actionLabel!),
            const Icon(Icons.chevron_right, size: 16),
          ],
        ),
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: titleColor,
                ),
              ),
              if (subtitle != null)
                Text(
                  subtitle!,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: mutedColor,
                  ),
                ),
            ],
          ),
        ),
        ?trailingWidget,
      ],
    );
  }
}
