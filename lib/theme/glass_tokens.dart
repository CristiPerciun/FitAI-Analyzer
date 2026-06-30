import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

/// Token del glassmorphism del redesign "NaturaVita / hand-drawn UI".
///
/// Stile di riferimento (CREATIVE HUB): sfondo a gradiente IRIDESCENTE/aurora,
/// card frosted NEUTRE che lasciano trasparire il gradiente colorato, bagliore
/// soffuso (cyan/rosa) in dark. I tint card restano traslucidi (alpha < ~0.65)
/// e poco saturi, così l'aurora dietro resta visibile attraverso il vetro.
@immutable
class GlassTokens extends ThemeExtension<GlassTokens> {
  const GlassTokens({
    required this.blurSigma,
    required this.useRealBlur,
    required this.tintColors,
    required this.heroTintColors,
    required this.borderColor,
    required this.glowColor,
    required this.secondaryGlowColor,
    required this.softShadow,
    required this.heroGlow,
    required this.backgroundGradient,
    required this.auroraColors,
    required this.navTint,
  });

  /// Intensità del blur smerigliato (sigma X/Y).
  final double blurSigma;

  /// Se false (es. web/PWA) salta il [BackdropFilter] e usa solo il tint
  /// traslucido sopra il gradiente.
  final bool useRealBlur;

  /// Tint traslucido (gradiente) delle card normali — NEUTRO/frosted.
  final List<Color> tintColors;

  /// Tint traslucido (gradiente) delle card hero — frosted, un filo più denso.
  final List<Color> heroTintColors;

  /// Bordo "vetro" 1px (rim frosted in light, edge cyan in dark).
  final Color borderColor;

  /// Colore del bagliore principale (trasparente in light).
  final Color glowColor;

  /// Secondo colore di bagliore per l'iridescenza (trasparente in light).
  final Color secondaryGlowColor;

  /// Ombra morbida neutra per le card normali.
  final List<BoxShadow> softShadow;

  /// Bagliore retroilluminato per le card hero (vuoto in light).
  final List<BoxShadow> heroGlow;

  /// Stop base del gradiente di sfondo globale (diagonale).
  final List<Color> backgroundGradient;

  /// Due tinte per i "wash" radiali sovrapposti (effetto aurora/iridescente).
  final List<Color> auroraColors;

  /// Tint traslucido della bottom nav bar in vetro.
  final Color navTint;

  /// Tema chiaro: crema → pastello iridescente, card frosted bianche, no glow.
  static const GlassTokens light = GlassTokens(
    blurSigma: 9.0,
    useRealBlur: !kIsWeb,
    // Card frosted bianche/calde: il pastello dietro traspare.
    tintColors: [Color(0x8CFFFFFF), Color(0x80FFF6EC)],
    heroTintColors: [Color(0x9EFFFFFF), Color(0x99FCF4EA)],
    borderColor: Color(0x99FFFFFF), // rim bianco @0.6 (effetto vetro)
    glowColor: Color(0x00000000),
    secondaryGlowColor: Color(0x00000000),
    softShadow: [
      BoxShadow(color: Color(0x14000000), blurRadius: 18, offset: Offset(0, 6)),
    ],
    heroGlow: [],
    // pesca → rosa → acqua → lavanda (pastello soffuso)
    backgroundGradient: [
      Color(0xFFFCEFE2),
      Color(0xFFF7E8EE),
      Color(0xFFE9EFF3),
      Color(0xFFEFEAF5),
    ],
    auroraColors: [Color(0x8CF8C9A8), Color(0x80C7DCEA)],
    navTint: Color(0x8CFFFFFF), // bianco @0.55
  );

  /// Tema scuro "deep glass": sfondo scuro NEUTRO (non blu) con bagliori di
  /// luce dietro le card; card TRASLUCIDE scure-neutre (charcoal) così il vetro
  /// smerigliato resta visibile (il blur cattura i wash cyan/rosa).
  static const GlassTokens dark = GlassTokens(
    blurSigma: 16.0,
    useRealBlur: !kIsWeb,
    // Charcoal NEUTRO traslucido (~0.55): il fondo smerigliato traspare = vetro.
    tintColors: [Color(0x8C1C1C1F), Color(0x82222226)],
    heroTintColors: [Color(0xA0262629), Color(0x962C2C30)],
    borderColor: Color(0x33FFFFFF), // rim bianco frosted @0.20 (edge del vetro)
    glowColor: Color(0xFFA9E8FF), // cyan soffuso
    secondaryGlowColor: Color(0xFFFFB3D9), // rosa iridescente
    softShadow: [
      BoxShadow(color: Color(0x80000000), blurRadius: 26, offset: Offset(0, 10)),
    ],
    heroGlow: [
      BoxShadow(
        color: Color(0x4DA9E8FF),
        blurRadius: 30,
        spreadRadius: 1,
        offset: Offset.zero,
      ),
      BoxShadow(color: Color(0x99000000), blurRadius: 26, offset: Offset(0, 10)),
    ],
    // grigio scuro neutro con un filo di variazione (dà "materia" al frost)
    backgroundGradient: [
      Color(0xFF202023),
      Color(0xFF27272B),
      Color(0xFF1A1A1D),
      Color(0xFF242428),
    ],
    // wash radiali di luce dietro le card (bagliore cyan/rosa) — fanno il vetro
    auroraColors: [Color(0x4DA9E8FF), Color(0x3DFFB3D9)],
    navTint: Color(0x99191A1D), // charcoal traslucido @0.60 (nav in vetro)
  );

  /// [Shadow] applicabili al glifo di un'icona (`Icon.shadows`/SVG) per il
  /// bagliore che segue la forma. Vuoto in light.
  List<Shadow> get iconGlowShadows => glowColor.a == 0
      ? const []
      : [
          Shadow(color: glowColor, blurRadius: 10),
          Shadow(color: glowColor.withValues(alpha: 0.6), blurRadius: 20),
        ];

  @override
  GlassTokens copyWith({
    double? blurSigma,
    bool? useRealBlur,
    List<Color>? tintColors,
    List<Color>? heroTintColors,
    Color? borderColor,
    Color? glowColor,
    Color? secondaryGlowColor,
    List<BoxShadow>? softShadow,
    List<BoxShadow>? heroGlow,
    List<Color>? backgroundGradient,
    List<Color>? auroraColors,
    Color? navTint,
  }) => GlassTokens(
    blurSigma: blurSigma ?? this.blurSigma,
    useRealBlur: useRealBlur ?? this.useRealBlur,
    tintColors: tintColors ?? this.tintColors,
    heroTintColors: heroTintColors ?? this.heroTintColors,
    borderColor: borderColor ?? this.borderColor,
    glowColor: glowColor ?? this.glowColor,
    secondaryGlowColor: secondaryGlowColor ?? this.secondaryGlowColor,
    softShadow: softShadow ?? this.softShadow,
    heroGlow: heroGlow ?? this.heroGlow,
    backgroundGradient: backgroundGradient ?? this.backgroundGradient,
    auroraColors: auroraColors ?? this.auroraColors,
    navTint: navTint ?? this.navTint,
  );

  static List<Color> _lerpColors(List<Color> a, List<Color> b, double t) {
    final n = a.length < b.length ? a.length : b.length;
    return [for (var i = 0; i < n; i++) Color.lerp(a[i], b[i], t)!];
  }

  @override
  GlassTokens lerp(ThemeExtension<GlassTokens>? other, double t) {
    if (other is! GlassTokens) return this;
    return GlassTokens(
      blurSigma: blurSigma + (other.blurSigma - blurSigma) * t,
      useRealBlur: t < 0.5 ? useRealBlur : other.useRealBlur,
      tintColors: _lerpColors(tintColors, other.tintColors, t),
      heroTintColors: _lerpColors(heroTintColors, other.heroTintColors, t),
      borderColor: Color.lerp(borderColor, other.borderColor, t)!,
      glowColor: Color.lerp(glowColor, other.glowColor, t)!,
      secondaryGlowColor: Color.lerp(
        secondaryGlowColor,
        other.secondaryGlowColor,
        t,
      )!,
      softShadow: t < 0.5 ? softShadow : other.softShadow,
      heroGlow: t < 0.5 ? heroGlow : other.heroGlow,
      backgroundGradient: _lerpColors(
        backgroundGradient,
        other.backgroundGradient,
        t,
      ),
      auroraColors: _lerpColors(auroraColors, other.auroraColors, t),
      navTint: Color.lerp(navTint, other.navTint, t)!,
    );
  }
}
