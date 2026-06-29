import 'package:fitai_analyzer/theme/app_card_theme.dart';
import 'package:fitai_analyzer/theme/app_spacing.dart';
import 'package:fitai_analyzer/ui/widgets/anim_progress_ring.dart';
import 'package:fitai_analyzer/ui/widgets/design/fit_hero_card.dart';
import 'package:fitai_analyzer/ui/widgets/design/fit_soft_card.dart';
import 'package:flutter/material.dart';

/// Anello di progresso con testo centrale, dentro una FitSoftCard o FitHeroCard.
/// Riusa [AnimProgressRing] esistente (nessuna reimplementazione).
class FitProgressRingCard extends StatelessWidget {
  const FitProgressRingCard({
    super.key,
    required this.progress,
    required this.centerValue,
    this.centerLabel,
    this.header,
    this.size = 152,
    this.strokeWidth = 11,
    this.hero = false,
    this.accentColor,
    this.padding = AppSpacing.pXl,
  });

  final double progress;
  final String centerValue;
  final String? centerLabel;

  /// Widget opzionale sopra l'anello (es. FitCardHeader).
  final Widget? header;
  final double size;
  final double strokeWidth;
  final bool hero;

  /// Override colore anello (accento semantico opzionale); default = primary.
  final Color? accentColor;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final cardTheme = theme.extension<AppCardTheme>();

    final accent =
        accentColor ??
        (hero ? (cardTheme?.contentColor ?? cs.onPrimary) : cs.primary);
    final track = hero
        ? cs.onPrimary.withValues(alpha: 0.15)
        : cs.onSurface.withValues(alpha: isDark ? 0.05 : 0.10);
    final valueColor = hero
        ? (cardTheme?.contentColor ?? cs.onPrimary)
        : cs.onSurface;
    final labelColor = hero
        ? (cardTheme?.contentColorMuted ?? cs.onPrimary.withValues(alpha: 0.9))
        : cs.onSurfaceVariant;

    final ring = SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          AnimProgressRing(
            progress: progress,
            size: size,
            strokeWidth: strokeWidth,
            accentColor: accent,
            trackColor: track,
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                centerValue,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: valueColor,
                ),
              ),
              if (centerLabel != null)
                Text(
                  centerLabel!,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: labelColor,
                  ),
                ),
            ],
          ),
        ],
      ),
    );

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (header != null) ...[header!, AppSpacing.gapL],
        Center(child: ring),
      ],
    );

    return hero
        ? FitHeroCard(padding: padding, child: content)
        : FitSoftCard(padding: padding, child: content);
  }
}
