import 'package:flutter/material.dart';

/// Estensione tema per le card con gradiente (stile Analisi AI).
/// Usata da: compact_activity_card, _MealCard, e dalla design library (FitHeroCard).
class AppCardTheme extends ThemeExtension<AppCardTheme> {
  const AppCardTheme({
    required this.gradientColors,
    required this.contentColor,
    required this.contentColorMuted,
    required this.shadowColor,
    required this.softShadowColor,
  });

  final List<Color> gradientColors;
  final Color contentColor;
  final Color contentColorMuted;
  final Color shadowColor;

  /// Ombra morbida e neutra per le card chiare (FitSoftCard). Diversa dalla
  /// shadow tinta-primary del gradiente hero: qui serve un nero a bassa opacità.
  final Color softShadowColor;

  /// Decoration per card con gradiente primary (raggio 16, legacy).
  BoxDecoration get gradientDecoration => BoxDecoration(
    gradient: LinearGradient(
      colors: gradientColors,
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    borderRadius: BorderRadius.circular(16),
    boxShadow: [
      BoxShadow(color: shadowColor, blurRadius: 12, offset: const Offset(0, 4)),
    ],
  );

  /// Decoration per le card "hero" charcoal del redesign (raggio 24, ombra ampia).
  BoxDecoration get heroDecoration => BoxDecoration(
    gradient: LinearGradient(
      colors: gradientColors,
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    borderRadius: BorderRadius.circular(24),
    boxShadow: [
      BoxShadow(color: shadowColor, blurRadius: 24, offset: const Offset(0, 8)),
    ],
  );

  /// Ombra morbida neutra per FitSoftCard (raggio 24).
  List<BoxShadow> get softShadow => [
    BoxShadow(
      color: softShadowColor,
      blurRadius: 20,
      offset: const Offset(0, 6),
    ),
  ];

  // NaturaVita: il content-color deriva dallo schema (onSurface/onSurfaceVariant)
  // così è scuro-foresta sul vetro pastello (light) e crema sul vetro foresta (dark).
  static AppCardTheme light(ColorScheme scheme) => AppCardTheme(
    // Gradiente pastello (verde acqua pallido → pesca pallido) per i card legacy
    // con gradiente opaco (compact_activity_card, _MealCard).
    gradientColors: const [Color(0xFFCDEBDD), Color(0xFFF7DFC8)],
    contentColor: scheme.onSurface,
    contentColorMuted: scheme.onSurfaceVariant,
    shadowColor: const Color(0x2E3A5F3A), // forest @0.18
    softShadowColor: const Color(0x0F000000), // black @0.06
  );

  static AppCardTheme dark(ColorScheme scheme) => AppCardTheme(
    // Foresta profonda → arancione profondo (bi-tono del tema scuro).
    gradientColors: const [Color(0xFF0F3B22), Color(0xFF3A2415)],
    contentColor: scheme.onSurface,
    contentColorMuted: scheme.onSurfaceVariant,
    shadowColor: const Color(0x80000000), // black @0.5
    softShadowColor: const Color(0x59000000), // black @0.35
  );

  @override
  ThemeExtension<AppCardTheme> copyWith({
    List<Color>? gradientColors,
    Color? contentColor,
    Color? contentColorMuted,
    Color? shadowColor,
    Color? softShadowColor,
  }) => AppCardTheme(
    gradientColors: gradientColors ?? this.gradientColors,
    contentColor: contentColor ?? this.contentColor,
    contentColorMuted: contentColorMuted ?? this.contentColorMuted,
    shadowColor: shadowColor ?? this.shadowColor,
    softShadowColor: softShadowColor ?? this.softShadowColor,
  );

  @override
  ThemeExtension<AppCardTheme> lerp(
    ThemeExtension<AppCardTheme>? other,
    double t,
  ) {
    if (other is! AppCardTheme) return this;
    return AppCardTheme(
      gradientColors: [
        Color.lerp(gradientColors[0], other.gradientColors[0], t)!,
        Color.lerp(gradientColors[1], other.gradientColors[1], t)!,
      ],
      contentColor: Color.lerp(contentColor, other.contentColor, t)!,
      contentColorMuted: Color.lerp(
        contentColorMuted,
        other.contentColorMuted,
        t,
      )!,
      shadowColor: Color.lerp(shadowColor, other.shadowColor, t)!,
      softShadowColor: Color.lerp(softShadowColor, other.softShadowColor, t)!,
    );
  }
}
