import 'package:fitai_analyzer/theme/app_card_theme.dart';
import 'package:flutter/material.dart';

/// Numero grande + unità + caption, stile metrica "2.5H" / "16 / 30 min".
class FitMetricDisplay extends StatelessWidget {
  const FitMetricDisplay({
    super.key,
    required this.value,
    this.unit,
    this.caption,
    this.align = CrossAxisAlignment.start,
    this.onHeroSurface = false,
    this.valueFontSize = 32,
  });

  final String value;
  final String? unit;
  final String? caption;
  final CrossAxisAlignment align;
  final bool onHeroSurface;
  final double valueFontSize;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final cardTheme = theme.extension<AppCardTheme>();

    final valueColor = onHeroSurface
        ? (cardTheme?.contentColor ?? cs.onPrimary)
        : cs.onSurface;
    final mutedColor = onHeroSurface
        ? (cardTheme?.contentColorMuted ?? cs.onPrimary.withValues(alpha: 0.9))
        : cs.onSurfaceVariant;

    final caab = align == CrossAxisAlignment.center
        ? TextAlign.center
        : TextAlign.start;

    return Column(
      crossAxisAlignment: align,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text.rich(
          TextSpan(
            text: value,
            style: TextStyle(
              fontSize: valueFontSize,
              fontWeight: FontWeight.w700,
              height: 1.0,
              color: valueColor,
            ),
            children: [
              if (unit != null)
                TextSpan(
                  text: ' $unit',
                  style: TextStyle(
                    fontSize: valueFontSize * 0.5,
                    fontWeight: FontWeight.w600,
                    color: mutedColor,
                  ),
                ),
            ],
          ),
          textAlign: caab,
        ),
        if (caption != null) ...[
          const SizedBox(height: 4),
          Text(
            caption!,
            textAlign: caab,
            style: theme.textTheme.labelMedium?.copyWith(color: mutedColor),
          ),
        ],
      ],
    );
  }
}
