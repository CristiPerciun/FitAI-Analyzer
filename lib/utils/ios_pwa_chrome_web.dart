// ignore_for_file: deprecated_member_use, avoid_web_libraries_in_flutter

import 'dart:html' as html;

import 'package:flutter/material.dart' hide Element;

/// Allinea `theme-color`, sfondo documento e (su iOS PWA) `apple-mobile-web-app-status-bar-style`
/// al tema **effettivo** dell’app, così la fascia sopra la safe area non resta bianca se iOS è in
/// “Chiaro” ma l’utente ha scelto tema scuro in app.
void syncIosPwaDocumentForTheme(Brightness brightness) {
  final isDark = brightness == Brightness.dark;
  const lightBg = '#F5F3F0';
  const darkBg = '#1C1C1E';
  final color = isDark ? darkBg : lightBg;

  final root = html.document.documentElement;
  root?.style.backgroundColor = color;
  html.document.body?.style.backgroundColor = color;
  root?.style.setProperty('color-scheme', isDark ? 'dark' : 'light');

  final head = html.document.head;
  if (head == null) return;

  for (final n in head.querySelectorAll('meta[name="theme-color"]')) {
    n.remove();
  }
  head.append(html.MetaElement()
    ..name = 'theme-color'
    ..content = color);

  final apple = head.querySelector('meta[name="apple-mobile-web-app-status-bar-style"]');
  final style = isDark ? 'black' : 'black-translucent';
  if (apple is html.MetaElement) {
    apple.content = style;
  } else {
    head.append(html.MetaElement()
      ..name = 'apple-mobile-web-app-status-bar-style'
      ..content = style);
  }
}
