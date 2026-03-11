import 'package:flutter/material.dart';

final appLightTheme = ThemeData(
  useMaterial3: true,
  colorScheme: ColorScheme.fromSeed(
    seedColor: const Color(0xFF4CAF50), // Verde principale
    brightness: Brightness.light,
  ),
  scaffoldBackgroundColor: const Color(0xFFE8F5E9), // Sfondo verde chiarissimo
  appBarTheme: const AppBarTheme(
    backgroundColor: Color(0xFF2E7D32),
    foregroundColor: Colors.white,
    elevation: 0,
    centerTitle: true,
  ),
  cardTheme: CardThemeData(
    elevation: 6,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    shadowColor: Colors.black26,
  ),
  textTheme: const TextTheme(
    headlineMedium: TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF37474F)),
    titleLarge: TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF37474F)),
  ),
);

final appDarkTheme = ThemeData(
  useMaterial3: true,
  colorScheme: ColorScheme.fromSeed(
    seedColor: const Color(0xFF4CAF50),
    brightness: Brightness.dark,
  ),
);
