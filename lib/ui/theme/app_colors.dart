import 'package:flutter/material.dart';

/// Colori centralizzati del progetto FitAI Analyzer.
/// Usare queste costanti invece di colori hardcoded per mantenere coerenza.
abstract final class AppColors {
  AppColors._();

  // --- Verde principale (brand / alimentazione) ---
  /// Verde principale (seed theme, pulsanti, card alimentazione).
  static const Color primaryGreen = Color(0xFF4CAF50);

  /// Verde scuro (AppBar, titoli, bordi alimentazione).
  static const Color darkGreen = Color(0xFF2E7D32);

  /// Sfondo verde chiarissimo (scaffold light).
  static const Color scaffoldLight = Color(0xFFE8F5E9);

  // --- Strava ---
  /// Arancione Strava (icone, grafici, badge Strava).
  static const Color stravaOrange = Color(0xFFFC4C02);

  // --- Testo e UI ---
  /// Grigio scuro per headline e titoli.
  static const Color textDark = Color(0xFF37474F);

  /// Grigio per hint e testo secondario.
  static const Color hint = Color(0xFF9E9E9E);

  /// Grigio medio (chevron, icone secondarie).
  static Color get hintMedium => Colors.grey.shade400;

  // --- Feedback ---
  /// Rosso per errori (SnackBar, icone errore).
  static Color get errorRed => Colors.red.shade700;

  // --- Neutri ---
  static const Color white = Colors.white;
  static const Color transparent = Colors.transparent;
  static const Color shadow = Colors.black26;

  /// Nero con alpha per ombre leggere.
  static Color shadowLight(double alpha) => Colors.black.withValues(alpha: alpha);
}
