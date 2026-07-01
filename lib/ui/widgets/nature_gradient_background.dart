import 'package:fitai_analyzer/theme/glass_tokens.dart';
import 'package:flutter/material.dart';

/// Sfondo a gradiente IRIDESCENTE/aurora dietro OGNI schermata (shell, route
/// pushate, auth/onboarding/launch). Inserito una sola volta via
/// `MaterialApp.builder`.
///
/// È la superficie che il glassmorphism delle card smeriglia: gli scaffold sono
/// trasparenti, quindi questo gradiente traspare ovunque. Composizione:
/// gradiente lineare base ([GlassTokens.backgroundGradient]) + due "wash"
/// radiali ([GlassTokens.auroraColors]) che danno l'effetto aurora/olografico
/// (pastello in light; navy/viola/teal in dark — mai verde).
class NatureGradientBackground extends StatelessWidget {
  const NatureGradientBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<GlassTokens>();
    final base =
        tokens?.backgroundGradient ??
        const [Color(0xFFFCEFE2), Color(0xFFE9EFF3), Color(0xFFEFEAF5)];
    final aurora =
        tokens?.auroraColors ?? const [Color(0x8CF8C9A8), Color(0x80C7DCEA)];

    return RepaintBoundary(
      child: Stack(
        fit: StackFit.expand,
        children: [
          // 1. Base lineare diagonale.
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: base,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
          // 2. Wash radiale caldo (alto-sinistra).
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: const Alignment(-0.8, -0.9),
                radius: 1.2,
                colors: [aurora.first, aurora.first.withValues(alpha: 0)],
              ),
            ),
          ),
          // 3. Wash radiale freddo (basso-destra).
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: const Alignment(0.9, 0.85),
                radius: 1.3,
                colors: [aurora.last, aurora.last.withValues(alpha: 0)],
              ),
            ),
          ),
          // 4. Contenuto dell'app.
          child,
        ],
      ),
    );
  }
}
