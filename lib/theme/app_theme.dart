import 'package:fitai_analyzer/ui/theme/app_colors.dart';
import 'package:flutter/material.dart';

final appLightTheme = ThemeData(
  useMaterial3: true,
  colorScheme: ColorScheme.fromSeed(
    seedColor: AppColors.primaryGreen,
    brightness: Brightness.light,
  ),
  scaffoldBackgroundColor: AppColors.scaffoldLight,
  appBarTheme: const AppBarTheme(
    backgroundColor: AppColors.darkGreen,
    foregroundColor: AppColors.white,
    elevation: 0,
    centerTitle: true,
  ),
  cardTheme: CardThemeData(
    elevation: 6,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    shadowColor: AppColors.shadow,
  ),
  textTheme: const TextTheme(
    headlineMedium: TextStyle(fontWeight: FontWeight.w700, color: AppColors.textDark),
    titleLarge: TextStyle(fontWeight: FontWeight.w600, color: AppColors.textDark),
  ),
);

final appDarkTheme = ThemeData(
  useMaterial3: true,
  colorScheme: ColorScheme.fromSeed(
    seedColor: AppColors.primaryGreen,
    brightness: Brightness.dark,
  ),
);
