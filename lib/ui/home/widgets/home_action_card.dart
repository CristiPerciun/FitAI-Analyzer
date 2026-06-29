import 'package:fitai_analyzer/theme/app_card_theme.dart';
import 'package:flutter/material.dart';

/// Card azione Home: stile soft del redesign (fill card, ombra morbida,
/// niente bordo colorato), altezza fissa, accento primary su icona/testo.
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
  static const double borderRadius = 18;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    final fill = theme.cardTheme.color ?? theme.colorScheme.surface;
    final softShadow = theme.extension<AppCardTheme>()?.softShadow;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: softShadow,
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
              ?trailing,
            ],
          ),
        ),
      ),
    );
  }
}
