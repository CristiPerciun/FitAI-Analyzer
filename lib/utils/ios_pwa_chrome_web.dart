// ignore_for_file: deprecated_member_use, avoid_web_libraries_in_flutter

import 'dart:html' as html;

import 'package:flutter/material.dart' hide Element;

/// Allinea `theme-color` e sfondo documento al tema **effettivo** dell’app, così la
/// fascia sopra la safe area (dietro la Dynamic Island) usa la tinta dell’app e non
/// il colore di sistema. I colori combaciano con la tinta alta del gradiente
/// (`GlassTokens.backgroundGradient[0]`) per evitare seam col rendering Flutter.
///
/// `apple-mobile-web-app-status-bar-style` è scelto in base al tema: **scuro** →
/// `black-translucent` (edge-to-edge sotto la Dynamic Island, icone bianche leggibili
/// sul gradiente scuro); **chiaro** → `default` (barra chiara con icone scure
/// leggibili). iOS legge questo valore al lancio, quindi la mutazione a runtime è
/// best-effort (utile su Android / alcune versioni iOS); il valore corretto al lancio
/// è garantito dal boot script in `web/index.html`.
void syncIosPwaDocumentForTheme(Brightness brightness) {
  final isDark = brightness == Brightness.dark;
  const lightBg = '#FCEFE2';
  const darkBg = '#202023';
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
  final style = isDark ? 'black-translucent' : 'default';
  if (apple is html.MetaElement) {
    apple.content = style;
  } else {
    head.append(html.MetaElement()
      ..name = 'apple-mobile-web-app-status-bar-style'
      ..content = style);
  }
}
