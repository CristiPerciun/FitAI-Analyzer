import 'dart:ui' show ImageFilter;

import 'package:fitai_analyzer/theme/glass_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Percorsi degli asset SVG line-art (stile "NaturaVita", disegno a tratto).
/// Sostituiscono le icone Material di sistema.
abstract final class NatureIcons {
  NatureIcons._();

  // Navigazione
  static const String home = 'assets/icons/ic_home.svg';
  static const String activity = 'assets/icons/ic_activity.svg';
  static const String nutrition = 'assets/icons/ic_nutrition.svg';
  static const String settings = 'assets/icons/ic_settings.svg';

  // Pilastri longevità
  static const String heart = 'assets/icons/ic_heart.svg';
  static const String strength = 'assets/icons/ic_strength.svg';
  static const String recovery = 'assets/icons/ic_recovery.svg';

  // Decorativi / illustrazioni
  static const String sun = 'assets/icons/ic_sun.svg';
  static const String leaf = 'assets/icons/ic_leaf.svg';
  static const String percorso = 'assets/illustrations/percorso_naturale.svg';
}

/// Icona/illustrazione vettoriale line-art tematizzata.
///
/// Tinge l'SVG col colore del tema ([color] o `onSurfaceVariant`) e, in tema
/// scuro, aggiunge il bagliore bioluminescente che SEGUE la forma del tratto
/// (copia sfocata sotto, via [ImageFiltered]). In light il glow è assente.
class NatureIcon extends StatelessWidget {
  const NatureIcon(
    this.asset, {
    super.key,
    this.size = 24,
    this.color,
    this.glow = false,
  });

  final String asset;
  final double size;
  final Color? color;

  /// Se true applica il bagliore neon (solo dove [GlassTokens.glowColor] è opaco).
  final bool glow;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = theme.extension<GlassTokens>()!;
    final tint = color ?? theme.colorScheme.onSurfaceVariant;

    final base = SvgPicture.asset(
      asset,
      width: size,
      height: size,
      colorFilter: ColorFilter.mode(tint, BlendMode.srcIn),
    );

    if (!glow || tokens.glowColor.a == 0) return base;

    final sigma = (size * 0.12).clamp(4.0, 18.0);
    return Stack(
      alignment: Alignment.center,
      children: [
        ImageFiltered(
          imageFilter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
          child: SvgPicture.asset(
            asset,
            width: size,
            height: size,
            colorFilter: ColorFilter.mode(tokens.glowColor, BlendMode.srcIn),
          ),
        ),
        base,
      ],
    );
  }
}
