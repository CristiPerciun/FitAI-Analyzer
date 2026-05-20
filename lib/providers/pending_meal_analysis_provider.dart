import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Pasto in attesa di analisi IA (card nel diario con foto o testo + loader).
class PendingMealAnalysis {
  const PendingMealAnalysis({
    required this.id,
    required this.dateStr,
    required this.mealTypeLabel,
    required this.mealLabelKey,
    this.imageBytes,
    this.mimeType,
    this.manualDescription,
    this.analyzing = true,
    this.errorMessage,
  });

  final String id;
  final String dateStr;
  /// Es. Colazione, Pranzo, Cena (per filtro UI).
  final String mealTypeLabel;
  /// Es. colazione, pranzo, cena (per [NutritionService.saveToFirestore]).
  final String mealLabelKey;
  final Uint8List? imageBytes;
  final String? mimeType;
  /// Descrizione testuale per inserimento manuale (senza foto).
  final String? manualDescription;
  final bool analyzing;
  final String? errorMessage;

  bool get isManualEntry =>
      manualDescription != null && manualDescription!.trim().isNotEmpty;
}

class PendingMealAnalysisNotifier extends Notifier<List<PendingMealAnalysis>> {
  @override
  List<PendingMealAnalysis> build() => [];

  String startAnalysis({
    required String dateStr,
    required String mealTypeLabel,
    required String mealLabelKey,
    required Uint8List imageBytes,
    required String mimeType,
  }) {
    final id =
        '${DateTime.now().microsecondsSinceEpoch}_${imageBytes.length}_${imageBytes.hashCode}';
    state = [
      ...state,
      PendingMealAnalysis(
        id: id,
        dateStr: dateStr,
        mealTypeLabel: mealTypeLabel,
        mealLabelKey: mealLabelKey,
        imageBytes: imageBytes,
        mimeType: mimeType,
      ),
    ];
    return id;
  }

  String startManualAnalysis({
    required String dateStr,
    required String mealTypeLabel,
    required String mealLabelKey,
    required String description,
  }) {
    final trimmed = description.trim();
    final id =
        '${DateTime.now().microsecondsSinceEpoch}_manual_${trimmed.hashCode}';
    state = [
      ...state,
      PendingMealAnalysis(
        id: id,
        dateStr: dateStr,
        mealTypeLabel: mealTypeLabel,
        mealLabelKey: mealLabelKey,
        manualDescription: trimmed,
      ),
    ];
    return id;
  }

  void finishWithError(String id, String message) {
    state = [
      for (final p in state)
        if (p.id == id)
          PendingMealAnalysis(
            id: p.id,
            dateStr: p.dateStr,
            mealTypeLabel: p.mealTypeLabel,
            mealLabelKey: p.mealLabelKey,
            imageBytes: p.imageBytes,
            mimeType: p.mimeType,
            manualDescription: p.manualDescription,
            analyzing: false,
            errorMessage: message,
          )
        else
          p,
    ];
  }

  void setRetrying(String id) {
    state = [
      for (final p in state)
        if (p.id == id)
          PendingMealAnalysis(
            id: p.id,
            dateStr: p.dateStr,
            mealTypeLabel: p.mealTypeLabel,
            mealLabelKey: p.mealLabelKey,
            imageBytes: p.imageBytes,
            mimeType: p.mimeType,
            manualDescription: p.manualDescription,
            analyzing: true,
            errorMessage: null,
          )
        else
          p,
    ];
  }

  void remove(String id) {
    state = state.where((p) => p.id != id).toList();
  }
}

final pendingMealAnalysisProvider =
    NotifierProvider<PendingMealAnalysisNotifier, List<PendingMealAnalysis>>(
  PendingMealAnalysisNotifier.new,
);
