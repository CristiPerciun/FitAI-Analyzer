import 'dart:ui' show ImageFilter;

import 'package:fitai_analyzer/providers/route_transition_provider.dart';
import 'package:fitai_analyzer/theme/app_card_theme.dart';
import 'package:fitai_analyzer/theme/app_spacing.dart';
import 'package:fitai_analyzer/theme/glass_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Card "hero" in vetro del redesign "NaturaVita" (raggio 24).
/// Replica la card in evidenza del riferimento, con tint più ricco e — in tema
/// scuro — il bagliore retroilluminato bioluminescente ([GlassTokens.heroGlow]).
///
/// I figli leggono i colori del contenuto da [AppCardTheme.contentColor] /
/// [AppCardTheme.contentColorMuted] (foresta su vetro pastello in light, crema
/// su vetro foresta in dark).
///
/// Spacing conforme a Material 3 (XL = 24dp).
class FitHeroCard extends ConsumerWidget {
  const FitHeroCard({
    super.key,
    required this.child,
    this.padding = AppSpacing.pXl,
    this.onTap,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final tokens = theme.extension<GlassTokens>()!;
    final cardTheme = theme.extension<AppCardTheme>()!;
    final borderRadius = BorderRadius.circular(24);

    final content = Padding(padding: padding, child: child);
    final inner = Material(
      type: MaterialType.transparency,
      borderRadius: borderRadius,
      clipBehavior: Clip.antiAlias,
      child: onTap == null
          ? content
          : InkWell(
              onTap: onTap,
              borderRadius: borderRadius,
              splashColor: cardTheme.contentColor.withValues(alpha: 0.08),
              highlightColor: cardTheme.contentColor.withValues(alpha: 0.04),
              child: content,
            ),
    );

    Widget surface = DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: tokens.heroTintColors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: tokens.borderColor, width: 1),
        borderRadius: borderRadius,
      ),
      child: inner,
    );

    // Blur disattivato durante le transizioni di rotta (solo tint): evita gli
    // scatti da ri-raster per-frame del BackdropFilter su desktop.
    if (tokens.useRealBlur && !ref.watch(routeTransitionActiveProvider)) {
      surface = BackdropFilter(
        filter: ImageFilter.blur(
          sigmaX: tokens.blurSigma,
          sigmaY: tokens.blurSigma,
        ),
        child: surface,
      );
    }

    // Glow/ombra fuori dal clip. In dark = bagliore neon, in light = ombra morbida.
    return RepaintBoundary(
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: borderRadius,
          boxShadow: tokens.heroGlow.isNotEmpty
              ? tokens.heroGlow
              : tokens.softShadow,
        ),
        child: ClipRRect(borderRadius: borderRadius, child: surface),
      ),
    );
  }
}
