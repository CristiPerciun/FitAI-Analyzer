import 'package:fitai_analyzer/theme/glass_tokens.dart';
import 'package:flutter/material.dart';

/// Sfondo a gradiente naturale dietro OGNI schermata (shell, route pushate,
/// auth/onboarding/launch). Inserito una sola volta via `MaterialApp.builder`.
///
/// È la superficie che il glassmorphism delle card smeriglia: gli scaffold sono
/// trasparenti ([ThemeData.scaffoldBackgroundColor] = transparent) così questo
/// gradiente traspare ovunque. Colori da [GlassTokens.backgroundGradient]
/// (crema→sabbia calda in light; carbone neutro in dark — NON verde).
class NatureGradientBackground extends StatelessWidget {
  const NatureGradientBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<GlassTokens>();
    final colors =
        tokens?.backgroundGradient ??
        const [Color(0xFFFDF5E6), Color(0xFFEAF3EC), Color(0xFFFBEEE2)];

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: colors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: child,
    );
  }
}
