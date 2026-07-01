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

  // Attività / allenamenti suggeriti dall'AI
  static const String run = 'assets/icons/ic_run.svg';
  static const String walk = 'assets/icons/ic_walk.svg';
  static const String bike = 'assets/icons/ic_bike.svg';
  static const String swim = 'assets/icons/ic_swim.svg';
  static const String yoga = 'assets/icons/ic_yoga.svg';
  static const String water = 'assets/icons/ic_water.svg';
  static const String timer = 'assets/icons/ic_timer.svg';
  static const String intensity = 'assets/icons/ic_intensity.svg';
  static const String repeat = 'assets/icons/ic_repeat.svg';

  // Azioni
  static const String plus = 'assets/icons/ic_plus.svg';
  static const String swap = 'assets/icons/ic_swap.svg';

  // Pasti (obiettivi alimentazione)
  static const String breakfast = 'assets/icons/ic_breakfast.svg';
  static const String lunch = 'assets/icons/ic_lunch.svg';
  static const String dinner = 'assets/icons/ic_dinner.svg';

  // Decorativi / illustrazioni
  static const String sun = 'assets/icons/ic_sun.svg';
  static const String leaf = 'assets/icons/ic_leaf.svg';
  static const String percorso = 'assets/illustrations/percorso_naturale.svg';

  /// Mappa un tipo di allenamento (testo libero dell'AI, es. "Corsa Zone 2",
  /// "Forza", "Riposo attivo") all'illustrazione più rappresentativa.
  /// Fallback: [activity] (battito/ECG generico).
  static String forWorkoutType(String tipo) {
    final t = tipo.toLowerCase();
    bool has(List<String> kws) => kws.any(t.contains);
    if (has(['cors', 'run', 'jog', 'sprint', 'maraton'])) return run;
    if (has(['cammin', 'walk', 'passegg', 'trekk', 'hik'])) return walk;
    if (has(['bici', 'cicl', 'bike', 'spinning', 'pedal'])) return bike;
    if (has(['nuot', 'swim', 'acqua', 'piscin'])) return swim;
    if (has(['yoga', 'mobil', 'stretch', 'flessib', 'pilates', 'equilibr'])) {
      return yoga;
    }
    if (has(['forza', 'pesi', 'strength', 'muscol', 'resist', 'palestra'])) {
      return strength;
    }
    if (has(['riposo', 'recup', 'rest', 'defatic', 'rigener', 'scarico'])) {
      return recovery;
    }
    if (has([
      'cuore',
      'cardio',
      'zone',
      'zona',
      'hiit',
      'vo2',
      'aerob',
      'intervall',
    ])) {
      return heart;
    }
    return activity;
  }

  /// Illustrazione per un pasto (titolo libero: Colazione/Pranzo/Cena/Spuntino).
  static String forMeal(String meal) {
    final m = meal.toLowerCase();
    if (m.contains('colaz') || m.contains('breakfast') || m.contains('mattin')) {
      return breakfast;
    }
    if (m.contains('cena') || m.contains('dinner') || m.contains('ser')) {
      return dinner;
    }
    if (m.contains('spunt') || m.contains('snack') || m.contains('merend')) {
      return leaf;
    }
    return lunch; // pranzo / generico
  }
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
    this.glowColor,
  });

  final String asset;
  final double size;
  final Color? color;

  /// Se true applica il bagliore che segue la forma del tratto.
  final bool glow;

  /// Colore del bagliore. Se null usa [GlassTokens.glowColor] (assente in light);
  /// forzarlo (es. accento di tema) permette l'illuminazione anche in tema chiaro.
  final Color? glowColor;

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

    final glowTint = glowColor ?? tokens.glowColor;
    if (!glow || glowTint.a == 0) return base;

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
            colorFilter: ColorFilter.mode(glowTint, BlendMode.srcIn),
          ),
        ),
        base,
      ],
    );
  }
}

/// Riquadro illustrazione tematizzato: box arrotondato con tinta accento
/// traslucida + [NatureIcon] al centro (con glow in dark). Usato nelle card
/// "obiettivi" di Allenamenti/Alimentazione e nei pilastri.
class NatureIconBadge extends StatelessWidget {
  const NatureIconBadge(
    this.asset, {
    super.key,
    required this.tint,
    this.boxSize = 56,
    this.iconSize = 32,
    this.radius = 18,
    this.glow = true,
  });

  final String asset;
  final Color tint;
  final double boxSize;
  final double iconSize;
  final double radius;
  final bool glow;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: boxSize,
      height: boxSize,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: tint.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: tint.withValues(alpha: 0.30), width: 1),
      ),
      child: NatureIcon(asset, color: tint, size: iconSize, glow: glow),
    );
  }
}
