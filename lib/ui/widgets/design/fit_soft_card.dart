import 'dart:ui' show ImageFilter;

import 'package:fitai_analyzer/providers/route_transition_provider.dart';
import 'package:fitai_analyzer/theme/app_spacing.dart';
import 'package:fitai_analyzer/theme/glass_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Card morbida del redesign "NaturaVita": vetro smerigliato (glassmorphism).
///
/// Struttura: ombra esterna (fuori dal clip) → ClipRRect → [BackdropFilter] →
/// tint traslucido + bordo "vetro". Il blur smeriglia il gradiente globale
/// ([NatureGradientBackground]) — per questo il tint deve restare traslucido.
///
/// - [glass] (default true): se false usa un fill solido (liste dense / opt-out).
/// - [color]: override del fill (solido); disattiva il tint/blur.
/// - Su web/Windows il `BackdropFilter` viene saltato ([GlassTokens.useRealBlur]):
///   resta il tint traslucido sopra il gradiente (~80% dell'effetto, costo minimo).
///
/// Spacing conforme a Material 3 (XL = 24dp).
class FitSoftCard extends ConsumerWidget {
  const FitSoftCard({
    super.key,
    required this.child,
    this.padding = AppSpacing.pXl,
    this.onTap,
    this.radius = 24,
    this.elevated = true,
    this.glass = true,
    this.color,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final double radius;

  /// Se true mostra l'ombra morbida; false = card piatta (per liste dense).
  final bool elevated;

  /// Se true usa il tint vetro traslucido; false = fill solido (superficie).
  final bool glass;

  /// Override del fill (solido). Se valorizzato disattiva tint e blur.
  final Color? color;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final tokens = theme.extension<GlassTokens>()!;
    final borderRadius = BorderRadius.circular(radius);

    final useTint = glass && color == null;
    // Durante una transizione di rotta il blur è disattivato (solo tint):
    // evita il ri-raster per-frame del BackdropFilter che causa scatti.
    final realBlur =
        useTint &&
        tokens.useRealBlur &&
        !ref.watch(routeTransitionActiveProvider);

    final content = Padding(padding: padding, child: child);
    final inner = Material(
      type: MaterialType.transparency,
      borderRadius: borderRadius,
      clipBehavior: Clip.antiAlias,
      child: onTap == null
          ? content
          : InkWell(onTap: onTap, borderRadius: borderRadius, child: content),
    );

    Widget surface = DecoratedBox(
      decoration: BoxDecoration(
        gradient: useTint
            ? LinearGradient(
                colors: tokens.tintColors,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : null,
        color: useTint ? null : (color ?? cs.surface),
        border: Border.all(color: tokens.borderColor, width: 1),
        borderRadius: borderRadius,
      ),
      child: inner,
    );

    if (realBlur) {
      surface = BackdropFilter(
        filter: ImageFilter.blur(
          sigmaX: tokens.blurSigma,
          sigmaY: tokens.blurSigma,
        ),
        child: surface,
      );
    }

    // L'ombra sta fuori dal ClipRRect, altrimenti verrebbe ritagliata.
    return RepaintBoundary(
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: borderRadius,
          boxShadow: elevated ? tokens.softShadow : null,
        ),
        child: ClipRRect(borderRadius: borderRadius, child: surface),
      ),
    );
  }
}
