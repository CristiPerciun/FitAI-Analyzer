// ignore_for_file: deprecated_member_use, avoid_web_libraries_in_flutter

import 'dart:async';
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

bool _pageShowHooked = false;

/// **Fix bottom bar non cliccabile al lancio (iOS PWA installata).**
///
/// Su iOS Safari come PWA *standalone*, al primo avvio la viewport comunicata al
/// motore non coincide con l'area realmente visibile finché non arriva un evento
/// `resize` — è esattamente ciò che accade ruotando il device (`orientationchange`
/// → `resize`). Fino a quel momento la regione di hit-test di Flutter non copre
/// la striscia inferiore e i tap sulla bottom bar non vengono recapitati: l'utente
/// deve ruotare per "sbloccarli". Qui replichiamo quel `resize` in modo sintetico,
/// così Flutter rimisura e la barra diventa cliccabile al lancio senza ruotare.
///
/// - Raffica sui primi ~800 ms (mentre status bar / safe-area di iOS si assestano),
///   così almeno un `resize` cade dopo l'assestamento della viewport.
/// - Ripetuto su `pageshow` (rientro dalla bfcache riaprendo la PWA).
///
/// No-op fuori dalla modalità standalone: in una scheda Safari il bug non si
/// verifica e non vogliamo layout extra sul web in scheda/desktop.
void nudgeIosPwaViewport() {
  if (!_isStandalonePwa()) return;

  _burstResize(const [0, 100, 250, 500, 800]);

  if (!_pageShowHooked) {
    _pageShowHooked = true;
    html.window.addEventListener('pageshow', (_) {
      _burstResize(const [0, 200, 500]);
    });
  }
}

/// `resize` sintetici sulla schedule (ms da adesso). È lo stesso evento generato
/// ruotando il device: forza Flutter a rimisurare la viewport / hit-test region.
void _burstResize(List<int> scheduleMs) {
  for (final ms in scheduleMs) {
    Timer(Duration(milliseconds: ms), () {
      html.window.dispatchEvent(html.Event('resize'));
    });
  }
}

/// PWA installata (aggiunta alla home): `display-mode: standalone` copre iOS 16.4+
/// e Android. È lo scenario in cui si verifica il bug.
bool _isStandalonePwa() {
  try {
    return html.window.matchMedia('(display-mode: standalone)').matches;
  } catch (_) {
    return false;
  }
}
