import 'package:fitai_analyzer/theme/app_card_theme.dart';
import 'package:flutter/material.dart';

/// Pulsante icona circolare con ombra morbida, da usare DENTRO le card
/// (reload/timer/info, chevron su/giù, navigazione mese). Non in AppBar.
class FitCircleIconButton extends StatelessWidget {
  const FitCircleIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.size = 44,
    this.iconSize = 20,
    this.tooltip,
    this.iconColor,
    this.onHeroSurface = false,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final double size;
  final double iconSize;
  final String? tooltip;

  /// Tinta icona (accento semantico opzionale); default neutro.
  final Color? iconColor;

  /// True quando il pulsante è posato su una card hero charcoal.
  final bool onHeroSurface;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final cardTheme = theme.extension<AppCardTheme>();

    final Color fill;
    final Color fg;
    final List<BoxShadow>? shadow;
    if (onHeroSurface) {
      fill = cs.onPrimary.withValues(alpha: 0.12);
      fg = iconColor ?? cs.onPrimary;
      shadow = null;
    } else {
      fill = isDark ? cs.surfaceContainerHighest : Colors.white;
      fg = iconColor ?? cs.onSurfaceVariant;
      shadow = [
        BoxShadow(
          color:
              cardTheme?.softShadowColor ??
              Colors.black.withValues(alpha: 0.06),
          blurRadius: 8,
          offset: const Offset(0, 2),
        ),
      ];
    }

    final button = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: fill,
        shape: BoxShape.circle,
        boxShadow: shadow,
      ),
      child: Material(
        type: MaterialType.transparency,
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onPressed,
          child: Icon(icon, size: iconSize, color: fg),
        ),
      ),
    );

    if (tooltip == null) return button;
    return Tooltip(message: tooltip!, child: button);
  }
}
