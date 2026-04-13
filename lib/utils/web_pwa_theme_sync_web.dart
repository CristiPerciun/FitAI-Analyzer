import 'package:flutter/material.dart' hide Element;
import 'package:web/web.dart';

/// Stessi esadecimali di [AppColors.backgroundLight] e scaffold dark in app_theme.dart.
const _lightBg = '#F5F3F0';
const _darkBg = '#1C1C1E';

/// Aggiorna sfondo documento e `theme-color` per PWA iOS (Chrome/Safari): la fascia
/// sopra la safe area segue il tema **effettivo** dell’app, non solo `prefers-color-scheme`.
void syncWebPwaChromeTheme(Brightness brightness) {
  final isDark = brightness == Brightness.dark;
  final color = isDark ? _darkBg : _lightBg;
  final root = document.documentElement;
  if (root != null) {
    final htmlEl = root as HTMLElement;
    htmlEl.style.backgroundColor = color;
    htmlEl.style.setProperty('color-scheme', isDark ? 'dark' : 'light');
  }
  document.body?.style.backgroundColor = color;

  final head = document.head;
  if (head == null) return;
  final metas = document.querySelectorAll('meta[name="theme-color"]');
  for (var i = 0; i < metas.length; i++) {
    final n = metas.item(i);
    if (n != null) (n as Element).remove();
  }
  final meta = HTMLMetaElement()
    ..name = 'theme-color'
    ..content = color;
  head.append(meta);
}
