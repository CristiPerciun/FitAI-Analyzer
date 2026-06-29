import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Notifier riusabile per azioni asincrone "one-shot" (salvataggi, invii, flussi
/// con spinner). Cattura loading **ed** errore in un singolo [AsyncValue],
/// coerente con l'uso pervasivo di `.when` / `ref.listen` nell'app.
///
/// Sostituisce i flag `bool _saving` / `_sending` / `_flowBusy` gestiti con
/// `setState`: la UI fa `ref.watch(provider).isLoading` per lo spinner e
/// `ref.listen(provider, ...)` per mostrare l'errore.
class AsyncActionNotifier extends AutoDisposeNotifier<AsyncValue<void>> {
  @override
  AsyncValue<void> build() => const AsyncData(null);

  bool get isBusy => state.isLoading;

  /// Esegue [action]: imposta loading, cattura eventuali errori nello stato.
  /// Ritorna `true` se completata senza errori.
  Future<bool> run(Future<void> Function() action) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(action);
    return !state.hasError;
  }
}

AutoDisposeNotifierProvider<AsyncActionNotifier, AsyncValue<void>>
_actionProvider() =>
    AutoDisposeNotifierProvider<AsyncActionNotifier, AsyncValue<void>>(
      AsyncActionNotifier.new,
    );

/// Flusso "salva obiettivo nutrizione + genera piano" (NutritionGoalScreen).
final nutritionGoalFlowActionProvider = _actionProvider();

/// Salvataggio combinato profilo + nutrizione (modifica onboarding).
final combinedSaveActionProvider = _actionProvider();

/// Invio messaggio di feedback.
final feedbackSendActionProvider = _actionProvider();
