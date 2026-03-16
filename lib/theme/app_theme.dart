import 'package:fitai_analyzer/theme/app_card_theme.dart';
import 'package:flutter/material.dart';

/// Colori centralizzati - tema minimal moderno.
abstract final class AppColors {
  AppColors._();

  static const Color backgroundLight = Color(0xFFF5F3F0);
  static const Color cardGrey = Color(0xFF999DA0);
  static const Color primary = Color(0xFF2C2C2C);
  static const Color stravaOrange = Color(0xFFFC4C02);
  static const Color garminBlue = Color(0xFF007CC2);
  static const Color error = Color(0xFFB00020);
  static const Color textDark = Color(0xFF2C2C2C);
  static const Color textMuted = Color(0xFF6B7280);
  static const Color hintMedium = Color(0xFF9CA3AF);
  static const Color white = Colors.white;
  static const Color transparent = Colors.transparent;
  static const Color shadow = Colors.black12;
  static Color shadowLight(double alpha) => Colors.black.withValues(alpha: alpha);
}

final _lightColorScheme = ColorScheme.light(
  primary: AppColors.primary,
  onPrimary: AppColors.white,
  surface: AppColors.backgroundLight,
  onSurface: AppColors.textDark,
  surfaceContainerHighest: AppColors.cardGrey,
  onSurfaceVariant: AppColors.textMuted,
  error: AppColors.error,
  onError: AppColors.white,
);

final appLightTheme = ThemeData(
  useMaterial3: true,
  colorScheme: _lightColorScheme,
  extensions: [AppCardTheme.light(_lightColorScheme)],
  scaffoldBackgroundColor: AppColors.backgroundLight,
  appBarTheme: const AppBarTheme(
    backgroundColor: AppColors.backgroundLight,
    foregroundColor: AppColors.textDark,
    elevation: 0,
    centerTitle: true,
    scrolledUnderElevation: 0,
  ),
  cardTheme: CardThemeData(
    color: AppColors.cardGrey,
    elevation: 0,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
  ),
  navigationBarTheme: const NavigationBarThemeData(
    backgroundColor: AppColors.white,
    surfaceTintColor: Colors.transparent,
    elevation: 8,
    height: 64,
  ),
  textTheme: const TextTheme(
    headlineMedium: TextStyle(fontWeight: FontWeight.w600, color: AppColors.textDark),
    titleLarge: TextStyle(fontWeight: FontWeight.w600, color: AppColors.textDark),
    bodyMedium: TextStyle(color: AppColors.textDark),
  ),
);



final _darkColorScheme = ColorScheme.dark(
    primary: AppColors.white,
    onPrimary: AppColors.textDark,
    surface: const Color(0xFF1C1C1E),
    onSurface: AppColors.white,
    surfaceContainerHighest: const Color(0xFF2C2C2E),
    onSurfaceVariant: AppColors.textMuted,
    error: AppColors.error,
    onError: AppColors.white,
);

final appDarkTheme = ThemeData(
  useMaterial3: true,
  colorScheme: _darkColorScheme,
  extensions: [AppCardTheme.dark(_darkColorScheme)],
  scaffoldBackgroundColor: const Color(0xFF1C1C1E),
  appBarTheme: const AppBarTheme(
    backgroundColor: Color(0xFF1C1C1E),
    foregroundColor: AppColors.white,
    elevation: 0,
    centerTitle: true,
    scrolledUnderElevation: 0,
  ),
  cardTheme: CardThemeData(
    color: const Color(0xFF2C2C2E),
    elevation: 0,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
  ),
  navigationBarTheme: const NavigationBarThemeData(
    backgroundColor: Color(0xFF252528),
    surfaceTintColor: Colors.transparent,
    elevation: 12,
    height: 64,
  ),
  textTheme: const TextTheme(
    headlineMedium: TextStyle(fontWeight: FontWeight.w600, color: AppColors.white),
    titleLarge: TextStyle(fontWeight: FontWeight.w600, color: AppColors.white),
    bodyMedium: TextStyle(color: AppColors.white),
  ),
);
