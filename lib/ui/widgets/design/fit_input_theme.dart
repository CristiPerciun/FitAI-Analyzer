import 'package:flutter/material.dart';

/// InputDecorationTheme morbido del redesign: campi "filled", angoli 16,
/// bordo hairline a riposo, focus primary, e messaggi di errore leggibili
/// anche su superficie scura (il maroon di default `cs.error` sparisce in dark).
///
/// Pensato per essere applicato a una sottostruttura via
/// `Theme(data: Theme.of(context).copyWith(inputDecorationTheme:
/// softInputDecorationTheme(context)))`, così lo stile resta circoscritto alla
/// schermata senza impatto globale sul resto dell'app.
InputDecorationTheme softInputDecorationTheme(BuildContext context) {
  final theme = Theme.of(context);
  final cs = theme.colorScheme;
  final isDark = theme.brightness == Brightness.dark;

  OutlineInputBorder border(Color color, [double width = 1]) =>
      OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: color, width: width),
      );

  // In dark il rosso M3 (0xFFB00020) ha contrasto ~1.9:1 sulla card: illeggibile.
  // Si usa un rosso chiaro (>=4.5:1 su 0xFF2C2C2E); su chiaro resta cs.error.
  final errorColor = isDark ? const Color(0xFFFF6B6B) : cs.error;

  return InputDecorationTheme(
    filled: true,
    fillColor: isDark
        ? Colors.white.withValues(alpha: 0.05)
        : cs.surfaceContainerHighest,
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    border: border(Colors.transparent),
    enabledBorder: border(cs.outline.withValues(alpha: 0.12)),
    focusedBorder: border(cs.primary, 1.6),
    errorBorder: border(errorColor.withValues(alpha: 0.8)),
    focusedErrorBorder: border(errorColor, 1.6),
    prefixIconColor: cs.onSurfaceVariant,
    errorStyle: theme.textTheme.bodySmall?.copyWith(color: errorColor),
    floatingLabelBehavior: FloatingLabelBehavior.auto,
  );
}
