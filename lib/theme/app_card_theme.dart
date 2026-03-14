import 'package:flutter/material.dart';

/// Estensione tema per le card con gradiente (stile Analisi AI).
/// Usata da: compact_activity_card, _MealCard.
class AppCardTheme extends ThemeExtension<AppCardTheme> {
  const AppCardTheme({
    required this.gradientColors,
    required this.contentColor,
    required this.contentColorMuted,
    required this.shadowColor,
  });

  final List<Color> gradientColors;
  final Color contentColor;
  final Color contentColorMuted;
  final Color shadowColor;

  /// Decoration per card con gradiente primary.
  BoxDecoration get gradientDecoration => BoxDecoration(
        gradient: LinearGradient(
          colors: gradientColors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: shadowColor,
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      );

  static AppCardTheme light(ColorScheme scheme) => AppCardTheme(
        gradientColors: [
          scheme.primary,
          scheme.primary.withValues(alpha: 0.8),
        ],
        contentColor: scheme.onPrimary,
        contentColorMuted: scheme.onPrimary.withValues(alpha: 0.9),
        shadowColor: scheme.primary.withValues(alpha: 0.3),
      );

  static AppCardTheme dark(ColorScheme scheme) => AppCardTheme(
        gradientColors: [
          scheme.primary,
          scheme.primary.withValues(alpha: 0.8),
        ],
        contentColor: scheme.onPrimary,
        contentColorMuted: scheme.onPrimary.withValues(alpha: 0.9),
        shadowColor: scheme.primary.withValues(alpha: 0.3),
      );

  @override
  ThemeExtension<AppCardTheme> copyWith({
    List<Color>? gradientColors,
    Color? contentColor,
    Color? contentColorMuted,
    Color? shadowColor,
  }) =>
      AppCardTheme(
        gradientColors: gradientColors ?? this.gradientColors,
        contentColor: contentColor ?? this.contentColor,
        contentColorMuted: contentColorMuted ?? this.contentColorMuted,
        shadowColor: shadowColor ?? this.shadowColor,
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
      contentColorMuted: Color.lerp(contentColorMuted, other.contentColorMuted, t)!,
      shadowColor: Color.lerp(shadowColor, other.shadowColor, t)!,
    );
  }
}
