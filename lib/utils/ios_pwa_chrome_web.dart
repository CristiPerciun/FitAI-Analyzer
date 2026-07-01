// ignore_for_file: deprecated_member_use, avoid_web_libraries_in_flutter

import 'dart:html' as html;

import 'package:flutter/material.dart' hide Element;

/// Allinea `theme-color` e sfondo documento al tema **effettivo** dell’app, così la
/// fascia sopra la safe area (dietro la Dynamic Island) usa la tinta dell’app e non
/// il colore di sistema. I colori combaciano con la tinta alta del gradiente
/// (`GlassTokens.backgroundGradient[0]`) per evitare seam col rendering Flutter.
///
/// `apple-mobile-web-app-status-bar-style` resta **sempre** `black-translucent`
/// (unico valore che rende il contenuto edge-to-edge sotto la status bar); iOS lo
/// legge una sola volta al lancio, quindi mutarlo a runtime è ininfluente lì, ma lo
/// teniamo coerente. Le icone di sistema con black-translucent sono bianche: la
/// leggibilità in tema chiaro è garantita dal velo scuro in [NatureGradientBackground].
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
  const style = 'black-translucent';
  if (apple is html.MetaElement) {
    apple.content = style;
  } else {
    head.append(html.MetaElement()
      ..name = 'apple-mobile-web-app-status-bar-style'
      ..content = style);
  }
}
