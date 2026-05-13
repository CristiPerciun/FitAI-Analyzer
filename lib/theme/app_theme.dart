import 'package:fitai_analyzer/theme/app_card_theme.dart';
import 'package:flutter/material.dart';

/// Colori centralizzati - tema minimal moderno.
abstract final class AppColors {
  AppColors._();

  static const Color backgroundLight = Color(0xFFF5F3F0);
  /// Usato solo nel tema scuro per card/superfici elevate.
  static const Color cardGrey = Color(0xFF999DA0);
  /// Superficie container per il tema chiaro: warm light-gray, distinguibile dallo sfondo.
  static const Color surfaceContainerLight = Color(0xFFE8E5E1);
  static const Color primary = Color(0xFF2C2C2C);
  static const Color stravaOrange = Color(0xFFFC4C02);
  static const Color garminBlue = Color(0xFF007CC2);
  /// Xiaomi / Mi Fitness (integrazione non ufficiale).
  static const Color miFitnessOrange = Color(0xFFFF6900);
  static const Color activityBurnBar = Color(0xFFDAAE63);
  static const Color error = Color(0xFFB00020);
  static const Color textDark = Color(0xFF2C2C2C);
  /// Testo muted per il tema scuro.
  static const Color textMuted = Color(0xFF6B7280);
  /// Testo muted per il tema chiaro: più scuro per superare il rapporto 4.5:1 su superfici chiare.
  static const Color textMutedLight = Color(0xFF4B5563);
  static const Color hintMedium = Color(0xFF9CA3AF);
  static const Color greenSave = Color.fromARGB(255, 24, 254, 44);
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
  // Superfici container chiare: warm gray distinguibile dallo sfondo senza essere troppo dark.
  surfaceContainerHighest: AppColors.surfaceContainerLight,
  // Testo secondario più scuro per garantire contrasto ≥ 4.5:1 su superfici chiare.
  onSurfaceVariant: AppColors.textMutedLight,
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
    // Card bianche in modalità chiara: testo scuro su bianco → contrasto ottimale.
    color: AppColors.white,
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
