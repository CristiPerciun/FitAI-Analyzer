import 'package:flutter/scheduler.dart' show SchedulerPhase;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// True mentre una transizione di rotta (push/pop) è in animazione.
///
/// I widget "glass" (FitSoftCard, FitHeroCard, barra nav, bolle feedback)
/// leggono questo flag per DISATTIVARE il `BackdropFilter` durante l'animazione.
/// Su desktop/Windows `GlassTokens.useRealBlur` è true e le tante superfici
/// smerigliate, ri-rasterizzate ad ogni frame mentre lo sfondo scorre sotto la
/// rotta entrante, saturano la GPU e fanno scattare la transizione ("a scatti").
/// Durante la transizione le superfici ripiegano sul solo tint traslucido — lo
/// stesso path già usato su web/PWA (~80% dell'effetto a costo ~0) — e il blur
/// torna nitido appena l'animazione si assesta.
class RouteTransitionController extends Notifier<bool> {
  /// Conteggio delle transizioni contemporaneamente in corso: gestisce
  /// push/pop sovrapposti senza spegnere il flag troppo presto.
  int _active = 0;

  @override
  bool build() => false;

  void begin() {
    _active++;
    if (!state) state = true;
  }

  void end() {
    if (_active > 0) _active--;
    if (_active == 0 && state) state = false;
  }
}

final routeTransitionActiveProvider =
    NotifierProvider<RouteTransitionController, bool>(
      RouteTransitionController.new,
    );

/// [NavigatorObserver] che accende [routeTransitionActiveProvider] durante
/// push/pop e lo spegne quando l'animazione della rotta si assesta. Va
/// registrato tra gli `observers` del `GoRouter` (root navigator).
class BlurTransitionObserver extends NavigatorObserver {
  BlurTransitionObserver(this._ref);

  final Ref _ref;

  /// Applica una mutazione dello stato in sicurezza: se siamo nella fase di
  /// build/layout/paint (Riverpod vieta le modifiche durante il build), la
  /// rimanda a fine frame; altrimenti (event handler, tick d'animazione) la
  /// esegue subito così il gate copre già il primo frame della transizione.
  void _safely(void Function() action) {
    final binding = WidgetsBinding.instance;
    if (binding.schedulerPhase == SchedulerPhase.persistentCallbacks) {
      binding.addPostFrameCallback((_) => action());
    } else {
      action();
    }
  }

  void _track(Route<dynamic>? route) {
    // Solo le transizioni di PAGINA: PageRoute (MaterialPageRoute e le pagine di
    // go_router). Esclude di proposito i PopupRoute fratelli (dialog, bottom
    // sheet, menu a tendina/_DropdownRoute): non devono spegnere il blur delle
    // superfici sottostanti mentre si aprono/chiudono.
    if (route is! PageRoute) return;
    final animation = route.animation;
    if (animation == null) return;
    // Rotta senza animazione (durata 0) o già assestata: niente da coprire.
    if (animation.status == AnimationStatus.completed ||
        animation.status == AnimationStatus.dismissed) {
      return;
    }
    final controller = _ref.read(routeTransitionActiveProvider.notifier);
    _safely(controller.begin);
    void listener(AnimationStatus status) {
      if (status == AnimationStatus.completed ||
          status == AnimationStatus.dismissed) {
        animation.removeStatusListener(listener);
        _safely(controller.end);
      }
    }

    animation.addStatusListener(listener);
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _track(route);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _track(route);
  }
}
