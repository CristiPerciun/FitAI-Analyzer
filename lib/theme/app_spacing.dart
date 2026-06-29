import 'package:flutter/material.dart';

/// Centralized spacing system based on Material Design 3 guidelines.
/// https://m3.material.io/styles/spacing/overview
abstract final class AppSpacing {
  AppSpacing._();

  // Spacing Scale Constants (multiples of 4dp/8dp)
  static const double none = 0;
  static const double xs = 4;
  static const double s = 8;
  static const double m = 12;
  static const double l = 16;
  static const double xl = 24;
  static const double xxl = 32;
  static const double xxxl = 40;
  static const double xxxxl = 48;
  static const double xxxxxl = 56;
  static const double xxxxxxl = 64;
  static const double xxxxxxxl = 72;
  static const double xxxxxxxxl = 80;

  // Pre-configured EdgeInsets for padding and margins
  static const EdgeInsets pNone = EdgeInsets.zero;
  static const EdgeInsets pXs = EdgeInsets.all(xs);
  static const EdgeInsets pS = EdgeInsets.all(s);
  static const EdgeInsets pM = EdgeInsets.all(m);
  static const EdgeInsets pL = EdgeInsets.all(l);
  static const EdgeInsets pXl = EdgeInsets.all(xl);
  static const EdgeInsets pXxl = EdgeInsets.all(xxl);

  // Symmetric Horizontal EdgeInsets
  static const EdgeInsets pxXs = EdgeInsets.symmetric(horizontal: xs);
  static const EdgeInsets pxS = EdgeInsets.symmetric(horizontal: s);
  static const EdgeInsets pxM = EdgeInsets.symmetric(horizontal: m);
  static const EdgeInsets pxL = EdgeInsets.symmetric(horizontal: l);
  static const EdgeInsets pxXl = EdgeInsets.symmetric(horizontal: xl);
  static const EdgeInsets pxXxl = EdgeInsets.symmetric(horizontal: xxl);

  // Symmetric Vertical EdgeInsets
  static const EdgeInsets pyXs = EdgeInsets.symmetric(vertical: xs);
  static const EdgeInsets pyS = EdgeInsets.symmetric(vertical: s);
  static const EdgeInsets pyM = EdgeInsets.symmetric(vertical: m);
  static const EdgeInsets pyL = EdgeInsets.symmetric(vertical: l);
  static const EdgeInsets pyXl = EdgeInsets.symmetric(vertical: xl);
  static const EdgeInsets pyXxl = EdgeInsets.symmetric(vertical: xxl);

  // Common mixed symmetric paddings
  static const EdgeInsets pSymmetricMS = EdgeInsets.symmetric(
    horizontal: m,
    vertical: s,
  );
  static const EdgeInsets pSymmetricLS = EdgeInsets.symmetric(
    horizontal: l,
    vertical: s,
  );
  static const EdgeInsets pSymmetricLM = EdgeInsets.symmetric(
    horizontal: l,
    vertical: m,
  );
  static const EdgeInsets pSymmetricXlL = EdgeInsets.symmetric(
    horizontal: xl,
    vertical: l,
  );

  // Pre-configured SizedBox gaps for Column/Row spacing
  static const SizedBox gapXs = SizedBox(width: xs, height: xs);
  static const SizedBox gapS = SizedBox(width: s, height: s);
  static const SizedBox gapM = SizedBox(width: m, height: m);
  static const SizedBox gapL = SizedBox(width: l, height: l);
  static const SizedBox gapXl = SizedBox(width: xl, height: xl);
  static const SizedBox gapXxl = SizedBox(width: xxl, height: xxl);
}
