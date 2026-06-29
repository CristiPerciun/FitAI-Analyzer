import 'package:flutter/material.dart';

/// Riquadro icona arrotondato (48x48, fill tinta@0.15, raggio 12).
/// De-duplica il pattern ripetuto in compact_activity_card, garmin_daily_stats,
/// weekly_sprint_card, pillar_grid.
///
/// [tint] è l'unico punto in cui si inietta un colore accento semantico
/// (Garmin blu, colore pilastro); di default resta neutro.
class FitIconBadge extends StatelessWidget {
  const FitIconBadge({
    super.key,
    required this.icon,
    this.tint,
    this.size = 48,
    this.radius = 12,
  });

  final IconData icon;
  final Color? tint;
  final double size;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final accent = tint ?? cs.onSurfaceVariant;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(radius),
      ),
      child: Icon(icon, color: tint ?? cs.onSurface, size: size * 0.54),
    );
  }
}
