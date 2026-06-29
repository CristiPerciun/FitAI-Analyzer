import 'package:fitai_analyzer/theme/app_spacing.dart';
import 'package:flutter/material.dart';

enum FitBadgeVariant { neutral, solid, outline }

/// Chip arrotondato (stile "+12 PROGRAMS", "Model 2.0", "Connected ✓").
class FitBadgePill extends StatelessWidget {
  const FitBadgePill({
    super.key,
    required this.label,
    this.leadingIcon,
    this.iconColor,
    this.variant = FitBadgeVariant.neutral,
    this.onHeroSurface = false,
  });

  final String label;
  final IconData? leadingIcon;
  final Color? iconColor;
  final FitBadgeVariant variant;
  final bool onHeroSurface;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final baseText = Theme.of(context).textTheme.labelSmall?.copyWith(
      fontWeight: FontWeight.w600,
      letterSpacing: 0.3,
    );

    Color fill;
    Color fg;
    BoxBorder? border;
    switch (variant) {
      case FitBadgeVariant.solid:
        fill = onHeroSurface ? cs.onPrimary : cs.primary;
        fg = onHeroSurface ? cs.primary : cs.onPrimary;
        border = null;
      case FitBadgeVariant.outline:
        fill = Colors.transparent;
        fg = onHeroSurface ? cs.onPrimary : cs.onSurfaceVariant;
        border = Border.all(
          color: (onHeroSurface ? cs.onPrimary : cs.outline).withValues(
            alpha: 0.4,
          ),
        );
      case FitBadgeVariant.neutral:
        fill = onHeroSurface
            ? cs.onPrimary.withValues(alpha: 0.14)
            : cs.surfaceContainerHighest;
        fg = onHeroSurface ? cs.onPrimary : cs.onSurfaceVariant;
        border = null;
    }

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.s,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(999),
        border: border,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (leadingIcon != null) ...[
            Icon(leadingIcon, size: 14, color: iconColor ?? fg),
            AppSpacing.gapXs,
          ],
          Text(label, style: baseText?.copyWith(color: fg)),
        ],
      ),
    );
  }
}
