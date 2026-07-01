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

bool _viewportListenersHooked = false;
bool _touchBackstopArmed = false;
Timer? _resizeDebounce;

/// **Fix bottom bar / pulsanti non cliccabili al lancio (iOS PWA installata).**
///
/// Su iOS Safari come PWA *standalone* la viewport comunicata al motore al primo
/// avvio non coincide con l'area realmente visibile: finché non arriva un evento
/// che fa rimisurare Flutter, l'intera hit-test region è sfasata e i tap non
/// vengono recapitati. Ruotando il device (`orientationchange` → cambio reale di
/// dimensioni) Flutter rimisura e tutto torna a funzionare: è il workaround che
/// l'utente scopre da solo.
///
/// **Lezione appresa (non ripetere):** una rimisura forzata *durante*
/// l'assestamento della viewport (es. eventi `resize` sintetici a raffica nei
/// primi ms) fa memorizzare a Flutter uno stato intermedio → offset verticale
/// persistente dei tap. La rimisura va fatta **solo a viewport ferma**.
///
/// Strategia (tutte le rimisure avvengono a viewport assestata, quindi pulite):
/// - **debounce**: su ogni variazione di `visualViewport`/orientamento, rimisura
///   200 ms **dopo l'ultima** variazione → mai a metà assestamento;
/// - **primo tocco**: backstop one-shot: la prima interazione avviene comunque a
///   viewport assestata, quindi una rimisura lì "sveglia" l'hit-test in modo
///   pulito, nel caso gli eventi `visualViewport` non scattino su alcune iOS;
/// - **pageshow**: rientro dalla bfcache (riapertura PWA) → ri-arma i backstop.
///
/// No-op fuori dalla modalità standalone (in scheda Safari il bug non si verifica).
void nudgeIosPwaViewport() {
  if (!_isStandalonePwa()) return;

  if (!_viewportListenersHooked) {
    _viewportListenersHooked = true;
    final vv = html.window.visualViewport;
    vv?.addEventListener('resize', (_) => _scheduleCleanResize());
    html.window.addEventListener(
      'orientationchange',
      (_) => _scheduleCleanResize(),
    );
    html.window.addEventListener('pageshow', (_) {
      _armFirstTouchBackstop();
      _scheduleCleanResize();
    });
  }

  _armFirstTouchBackstop();
}

/// Rimisura 200 ms dopo l'ultima variazione della viewport (debounce): garantisce
/// che Flutter misuri solo quando le dimensioni hanno smesso di cambiare.
void _scheduleCleanResize() {
  _resizeDebounce?.cancel();
  _resizeDebounce = Timer(const Duration(milliseconds: 200), _cleanResize);
}

/// Backstop: alla PRIMA interazione (viewport ormai assestata) forza una rimisura
/// pulita e si disarma. Cattura in fase capture così scatta anche se il tap cade
/// in una zona "morta" prima che l'hit-test sia allineato.
void _armFirstTouchBackstop() {
  if (_touchBackstopArmed) return;
  _touchBackstopArmed = true;
  html.EventListener? onTouch;
  onTouch = (_) {
    _touchBackstopArmed = false;
    html.document.removeEventListener('touchstart', onTouch, true);
    _cleanResize();
  };
  html.document.addEventListener('touchstart', onTouch, true);
}

/// Rimisura pulita: azzera un eventuale scroll della viewport (possibile causa di
/// offset) e notifica a Flutter di rileggere le dimensioni (stesso percorso della
/// rotazione). A viewport ferma non introduce sfasamenti.
void _cleanResize() {
  if (html.window.scrollX != 0 || html.window.scrollY != 0) {
    html.window.scrollTo(0, 0);
  }
  html.window.dispatchEvent(html.Event('resize'));
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
