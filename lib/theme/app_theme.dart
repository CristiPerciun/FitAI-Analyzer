import 'package:fitai_analyzer/theme/app_card_theme.dart';
import 'package:fitai_analyzer/theme/glass_tokens.dart';
import 'package:flutter/material.dart';

export 'app_spacing.dart';
export 'glass_tokens.dart';

/// Colori centralizzati — tema "NaturaVita / Magical Natural UI".
abstract final class AppColors {
  AppColors._();

  // ---- Palette NaturaVita ----------------------------------------------
  // LIGHT — crema + pastello, testo foresta.
  static const Color cream = Color(0xFFFDF5E6); // sfondo / onPrimary light
  static const Color forestText = Color(0xFF3A5F3A); // testo primario light
  // Testo secondario: scurito a #4F7A4F per contrasto AA (~5:1) su card frosted.
  static const Color forestTextMuted = Color(0xFF4F7A4F);
  static const Color accentGreen = Color(
    0xFF95D595,
  ); // accent attivo (secondary)
  static const Color natureContainerLight = Color(0xFFE3F0E8); // aqua pallido

  // DARK — foresta profonda + bioluminescenza.
  static const Color deepForest = Color(0xFF0A2F1A); // sfondo scuro
  static const Color deepForestContainer = Color(0xFF103A24);
  static const Color creamText = Color(0xFFFDFDFD); // testo primario dark
  static const Color paleGreenText = Color(0xFFD4F1D4); // testo secondario dark
  static const Color biolumGreen = Color(
    0xFF5DFFD4,
  ); // accent neon (primary dark)
  static const Color deepOrange = Color(0xFFFF7A3D); // accent secondario dark

  // ---- Legacy / neutri (mantenuti per retrocompatibilità) ---------------
  static const Color backgroundLight = cream;
  static const Color cardGrey = Color(0xFF999DA0);
  static const Color surfaceContainerLight = natureContainerLight;
  static const Color primary = forestText;

  // ---- Brand di terze parti (NON modificare: fedeltà ai marchi) ---------
  static const Color stravaOrange = Color(0xFFFC4C02);
  static const Color garminBlue = Color(0xFF007CC2);

  /// Xiaomi / Mi Fitness (integrazione non ufficiale).
  static const Color miFitnessOrange = Color(0xFFFF6900);

  // ---- Grafici (ri-armonizzati ai toni natura) --------------------------
  static const Color activityBurnBar = Color(0xFFC9A227); // ambra
  static const Color caloricDeficitGoalBar = Color(0xFF5D8B5D); // forest medio
  static const Color caloricIntakeBar = Color(0xFFE8C66B); // miele
  static const Color caloricSurplusBar = Color(0xFFB5894A); // bronzo
  static const Color longevityPurple = Color(0xFFC9A227); // ambra (ex viola)

  // ---- Testo & feedback -------------------------------------------------
  static const Color error = Color(0xFFB00020);
  static const Color textDark = forestText;
  static const Color textMuted = forestTextMuted;
  static const Color textMutedLight = forestTextMuted;
  static const Color hintMedium = Color(0xFF9CA3AF);
  static const Color greenSave = biolumGreen; // highlight "salvato" → neon
  static const Color white = Colors.white;
  static const Color transparent = Colors.transparent;
  static const Color shadow = Colors.black12;
  static Color shadowLight(double alpha) =>
      Colors.black.withValues(alpha: alpha);
}

/// Famiglie di font del tema (hand-drawn UI).
abstract final class AppFonts {
  AppFonts._();

  /// Sans "disegnato a mano" ma leggibile: titoli, testi, navigazione.
  static const String sans = 'ShantellSans';

  /// Manoscritto corsivo: nomi utente, saluti, accenti.
  static const String script = 'Caveat';
}

/// Helper tipografico per il carattere manoscritto (Caveat).
/// Usato per nomi utente e saluti (es. greeting in Home).
abstract final class AppText {
  AppText._();

  static TextStyle script({
    double fontSize = 28,
    FontWeight fontWeight = FontWeight.w400,
    Color? color,
    double? height,
  }) => TextStyle(
    fontFamily: AppFonts.script,
    fontSize: fontSize,
    fontWeight: fontWeight,
    color: color,
    height: height,
  );

  /// Titolo di sezione in stile foto: sans geometrico, maiuscolo spaziato.
  /// Da usare con testo già in MAIUSCOLO (`.toUpperCase()`).
  static TextStyle sectionTitle({double fontSize = 13, Color? color}) =>
      TextStyle(
        fontFamily: AppFonts.sans,
        fontSize: fontSize,
        fontWeight: FontWeight.w600,
        letterSpacing: 1.5,
        color: color,
      );
}

// ============================== LIGHT ===================================
final _lightColorScheme = const ColorScheme.light(
  // Accento TEAL profondo (non verde): alto contrasto su crema, coerente col
  // cyan del tema scuro. Il verde su chiaro era poco gradevole/contrastato.
  primary: Color(0xFF1C7A8C),
  onPrimary: AppColors.cream,
  secondary: Color(0xFF5FB6C9), // teal laguna (accent secondario)
  onSecondary: Color(0xFF062E36),
  tertiary: Color(0xFF1C7A8C),
  onTertiary: AppColors.cream,
  surface: AppColors.cream, // solido: modali/dialog/snackbar leggibili
  // FONT NERO: il testo (onSurface) è quasi-nero, non più verde.
  onSurface: Color(0xFF1A1A1A),
  surfaceContainerHighest: Color(0xFFEDE7DC), // beige neutro (non più verdino)
  onSurfaceVariant: Color(0xFF5A5A5A), // testo secondario grigio neutro
  outline: Color(0xFFA8A096), // bordo grigio caldo neutro (non più verde)
  error: AppColors.error,
  onError: AppColors.white,
);

final appLightTheme = ThemeData(
  useMaterial3: true,
  fontFamily: AppFonts.sans,
  colorScheme: _lightColorScheme,
  extensions: [AppCardTheme.light(_lightColorScheme), GlassTokens.light],
  // Trasparente: il gradiente globale (NatureGradientBackground) traspare.
  scaffoldBackgroundColor: Colors.transparent,
  appBarTheme: const AppBarTheme(
    backgroundColor: Colors.transparent,
    foregroundColor: Color(0xFF1A1A1A), // titoli neri
    surfaceTintColor: Colors.transparent,
    elevation: 0,
    centerTitle: true,
    scrolledUnderElevation: 0,
  ),
  cardTheme: CardThemeData(
    color: const Color(0xFFFBF7EF), // warm white per i raw Card
    elevation: 0,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
  ),
  navigationBarTheme: NavigationBarThemeData(
    backgroundColor: Colors.transparent,
    surfaceTintColor: Colors.transparent,
    indicatorColor: const Color(0xFF5FB6C9).withValues(alpha: 0.30),
    elevation: 0,
    height: 64,
    // Font nav nero/grigio (l'accento teal resta su icona attiva + indicatore).
    iconTheme: WidgetStateProperty.resolveWith(
      (states) => states.contains(WidgetState.selected)
          ? const IconThemeData(color: Color(0xFF1C7A8C))
          : const IconThemeData(color: Color(0xFF5A5A5A)),
    ),
    labelTextStyle: WidgetStateProperty.resolveWith(
      (states) => TextStyle(
        fontFamily: AppFonts.sans,
        fontSize: 11,
        fontWeight: states.contains(WidgetState.selected)
            ? FontWeight.w600
            : FontWeight.w500,
        color: states.contains(WidgetState.selected)
            ? const Color(0xFF1A1A1A)
            : const Color(0xFF5A5A5A),
      ),
    ),
  ),
  textTheme: const TextTheme(
    headlineMedium: TextStyle(fontWeight: FontWeight.w600),
    titleLarge: TextStyle(fontWeight: FontWeight.w600),
  ),
);

// ============================== DARK ====================================
// Tema scuro "deep": superfici quasi-nere NEUTRE (non blu), accenti cyan/rosa
// solo come bagliore (play of light). Font bianco.
final _darkColorScheme = const ColorScheme.dark(
  primary: Color(0xFF9FE6FF), // cyan soffuso (accenti/icone attive)
  onPrimary: Color(0xFF12162A),
  secondary: Color(0xFFFFB3D9), // rosa iridescente
  onSecondary: Color(0xFF3A1228),
  tertiary: Color(0xFFE2E2E6),
  onTertiary: Color(0xFF17171A),
  surface: Color(0xFF1C1C1F), // grigio molto scuro neutro (modali/dialog)
  onSurface: Color(0xFFFDFDFD), // FONT BIANCO
  surfaceContainerHighest: Color(0xFF26262A),
  onSurfaceVariant: Color(0xFFD2D2D6), // grigio chiaro neutro (testo secondario)
  outline: Color(0xFF3A3A3F),
  error: Color(0xFFFF6B6B),
  onError: Color(0xFF2A0E12),
);

final appDarkTheme = ThemeData(
  useMaterial3: true,
  fontFamily: AppFonts.sans,
  colorScheme: _darkColorScheme,
  extensions: [AppCardTheme.dark(_darkColorScheme), GlassTokens.dark],
  scaffoldBackgroundColor: Colors.transparent,
  appBarTheme: const AppBarTheme(
    backgroundColor: Colors.transparent,
    foregroundColor: AppColors.creamText,
    surfaceTintColor: Colors.transparent,
    elevation: 0,
    centerTitle: true,
    scrolledUnderElevation: 0,
  ),
  cardTheme: CardThemeData(
    color: AppColors.deepForestContainer,
    elevation: 0,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
  ),
  navigationBarTheme: NavigationBarThemeData(
    backgroundColor: Colors.transparent,
    surfaceTintColor: Colors.transparent,
    indicatorColor: const Color(0xFF9FE6FF).withValues(alpha: 0.18),
    elevation: 0,
    height: 64,
    // Font nav bianco/grigio (l'accento cyan resta su icona attiva + indicatore).
    iconTheme: WidgetStateProperty.resolveWith(
      (states) => states.contains(WidgetState.selected)
          ? const IconThemeData(color: Color(0xFF9FE6FF))
          : const IconThemeData(color: Color(0xFFD2D2D6)),
    ),
    labelTextStyle: WidgetStateProperty.resolveWith(
      (states) => TextStyle(
        fontFamily: AppFonts.sans,
        fontSize: 11,
        fontWeight: states.contains(WidgetState.selected)
            ? FontWeight.w600
            : FontWeight.w500,
        color: states.contains(WidgetState.selected)
            ? const Color(0xFFFDFDFD)
            : const Color(0xFFD2D2D6),
      ),
    ),
  ),
  textTheme: const TextTheme(
    headlineMedium: TextStyle(fontWeight: FontWeight.w600),
    titleLarge: TextStyle(fontWeight: FontWeight.w600),
  ),
);
