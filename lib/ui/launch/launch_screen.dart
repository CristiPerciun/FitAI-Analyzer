import 'package:fitai_analyzer/theme/app_theme.dart';
import 'package:flutter/material.dart';

/// Schermata unica di avvio: logo, titolo e loader finché auth/profilo/dati Home non sono pronti.
class LaunchScreen extends StatelessWidget {
  const LaunchScreen({super.key});

  static const _logoSize = 120.0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: theme.brightness == Brightness.dark
              ? [
                  scheme.surface,
                  scheme.surfaceContainerHighest.withValues(alpha: 0.6),
                ]
              : [
                  AppColors.backgroundLight,
                  AppColors.backgroundLight.withValues(alpha: 0.92),
                ],
        ),
      ),
      child: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(28),
                  child: Image.asset(
                    'assets/branding/app_icon.png',
                    width: _logoSize,
                    height: _logoSize,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Icon(
                      Icons.health_and_safety_outlined,
                      size: _logoSize * 0.55,
                      color: scheme.primary,
                    ),
                  ),
                ),
                const SizedBox(height: 28),
                Text(
                  'FitAI Analyzer',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: scheme.onSurface,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Caricamento in corso…',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 40),
                SizedBox(
                  width: 36,
                  height: 36,
                  child: CircularProgressIndicator(
                    strokeWidth: 3,
                    color: scheme.primary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
