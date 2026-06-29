import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

/// Token del glassmorphism del redesign "NaturaVita / Magical Natural UI".
///
/// Separati da [AppCardTheme] (che resta per i content-color hero): qui vivono
/// solo decorazione di vetro (blur, tint traslucido, bordo, bagliore) e il
/// gradiente di sfondo globale. Consumati da `FitSoftCard`, `FitHeroCard`,
/// dalla nav bar e da `NatureGradientBackground`.
///
/// Vincolo chiave: i tint devono restare TRASLUCIDI (alpha < ~0.65) altrimenti
/// il [BackdropFilter] dietro non si vede. In light il glow è assente (luce
/// diffusa); in dark è bioluminescente (verde #5DFFD4 / arancione #FF7A3D).
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
    required this.navTint,
  });

  /// Intensità del blur smerigliato (sigma X/Y).
  final double blurSigma;

  /// Se false (es. web/PWA) salta il [BackdropFilter] e usa solo il tint
  /// traslucido sopra il gradiente: ~80% dell'effetto a una frazione del costo.
  final bool useRealBlur;

  /// Tint traslucido (gradiente) delle card normali.
  final List<Color> tintColors;

  /// Tint traslucido (gradiente) delle card hero — più ricco.
  final List<Color> heroTintColors;

  /// Bordo "vetro" 1px (rim highlight in light, edge neon in dark).
  final Color borderColor;

  /// Colore del bagliore principale (trasparente in light).
  final Color glowColor;

  /// Secondo colore di bagliore per il look bi-tono (trasparente in light).
  final Color secondaryGlowColor;

  /// Ombra morbida neutra per le card normali.
  final List<BoxShadow> softShadow;

  /// Bagliore retroilluminato per le card hero (vuoto in light).
  final List<BoxShadow> heroGlow;

  /// Gradiente di sfondo globale dietro a tutte le schermate.
  final List<Color> backgroundGradient;

  /// Tint traslucido della bottom nav bar in vetro.
  final Color navTint;

  /// Tema chiaro: crema/pastello, luce diffusa, nessun glow.
  static const GlassTokens light = GlassTokens(
    blurSigma: 9.0,
    useRealBlur: !kIsWeb,
    // #DFF3EC@0.55 → #FBEBDD@0.55 (verde acqua pallido → pesca pallido)
    tintColors: [Color(0x8CDFF3EC), Color(0x8CFBEBDD)],
    // #CDEBDD@0.62 → #F7DFC8@0.62 (più saturo per le hero)
    heroTintColors: [Color(0x9ECDEBDD), Color(0x9EF7DFC8)],
    borderColor: Color(0x73FFFFFF), // rim bianco @0.45 (effetto vetro)
    glowColor: Color(0x00000000),
    secondaryGlowColor: Color(0x00000000),
    softShadow: [
      BoxShadow(color: Color(0x0F000000), blurRadius: 20, offset: Offset(0, 6)),
    ],
    heroGlow: [],
    // crema → sabbia calda (NON verde; le card pastello risaltano)
    backgroundGradient: [
      Color(0xFFFDF5E6),
      Color(0xFFFAEFE0),
      Color(0xFFF4E7D6),
    ],
    navTint: Color(0x99FDF8EE), // crema @0.6
  );

  /// Tema scuro: foresta profonda, bagliore bioluminescente forte.
  static const GlassTokens dark = GlassTokens(
    blurSigma: 14.0,
    useRealBlur: !kIsWeb,
    // #0F3B22@0.50 → #3A2415@0.45 (foresta profonda → arancione profondo)
    tintColors: [Color(0x800F3B22), Color(0x733A2415)],
    heroTintColors: [Color(0x99103A24), Color(0x8C3A2415)],
    borderColor: Color(0x2E5DFFD4), // edge neon @0.18
    glowColor: Color(0xFF5DFFD4),
    secondaryGlowColor: Color(0xFFFF7A3D),
    softShadow: [
      BoxShadow(color: Color(0x59000000), blurRadius: 24, offset: Offset(0, 8)),
    ],
    // core neon stretto + profondità
    heroGlow: [
      BoxShadow(
        color: Color(0x595DFFD4),
        blurRadius: 32,
        spreadRadius: 2,
        offset: Offset.zero,
      ),
      BoxShadow(color: Color(0x8C0A2F1A), blurRadius: 24, offset: Offset(0, 8)),
    ],
    // carbone neutro (NON verde; le card foresta/neon risaltano sopra)
    backgroundGradient: [
      Color(0xFF1A1B1E),
      Color(0xFF141519),
      Color(0xFF0E0F12),
    ],
    navTint: Color(0x99181A1D), // carbone neutro @0.6
  );

  /// Set di [BoxShadow] per il bagliore attorno a un box (solo dark).
  /// In light ritorna lista vuota (nessun glow).
  List<BoxShadow> get iconGlow => glowColor.a == 0
      ? const []
      : [
          BoxShadow(
            color: glowColor.withValues(alpha: 0.65),
            blurRadius: 12,
            spreadRadius: 1,
          ),
          BoxShadow(
            color: glowColor.withValues(alpha: 0.30),
            blurRadius: 24,
            spreadRadius: 4,
          ),
        ];

  /// [Shadow] applicabili al glifo di un'icona (`Icon.shadows`) per il bagliore
  /// neon che segue la forma. Vuoto in light.
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
      navTint: Color.lerp(navTint, other.navTint, t)!,
    );
  }
}
