import 'package:fitai_analyzer/ui/widgets/nature_icon.dart';
import 'package:flutter/material.dart';

/// Card azione Home in stile hand-drawn: "pill" con accento di tema (fill +
/// bordo tenui), icona disegnata ([NatureIcon]) con bagliore in dark, testo
/// accentato. Accetta un asset SVG ([asset]); in fallback usa [icon] Material.
class HomeActionCard extends StatelessWidget {
  const HomeActionCard({
    super.key,
    required this.onTap,
    this.asset,
    this.icon = Icons.add,
    this.label,
    this.semanticLabel,
    this.trailing,
  });

  final VoidCallback onTap;

  /// Asset SVG line-art (preferito). Se null usa [icon].
  final String? asset;
  final IconData icon;
  final String? label;
  final String? semanticLabel;

  /// Widget opzionale a destra (es. pulsante rimuovi widget).
  final Widget? trailing;

  static const double height = 56;
  static const double borderRadius = 18;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final accent = cs.primary;

    final iconWidget = asset != null
        ? NatureIcon(asset!, color: accent, size: 26, glow: true)
        : Icon(icon, color: accent, size: 26);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: accent.withValues(alpha: isDark ? 0.16 : 0.10),
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(
          color: accent.withValues(alpha: isDark ? 0.45 : 0.35),
          width: 1.2,
        ),
      ),
      child: SizedBox(
        height: height,
        child: Material(
          type: MaterialType.transparency,
          borderRadius: BorderRadius.circular(borderRadius),
          clipBehavior: Clip.antiAlias,
          child: Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: onTap,
                  child: Semantics(
                    button: true,
                    label: semanticLabel ?? label,
                    child: Center(
                      child: label == null
                          ? iconWidget
                          : Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                iconWidget,
                                const SizedBox(width: 10),
                                Text(
                                  label!,
                                  style: theme.textTheme.titleSmall?.copyWith(
                                    color: accent,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                ),
              ),
              ?trailing,
            ],
          ),
        ),
      ),
    );
  }
}
