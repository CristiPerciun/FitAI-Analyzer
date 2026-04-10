import 'package:cloud_firestore/cloud_firestore.dart';

/// Obiettivo di allenamento giornaliero generato dall'AI (prompt unificato).
/// Salvato in `users/{uid}/ai_current/allenamenti`.
/// Mostra la card "Obiettivo allenamento di oggi" nella pagina Allenamenti.
class AiCurrentAllenamentiModel {
  const AiCurrentAllenamentiModel({
    required this.tipo,
    required this.descrizione,
    this.durataMins = 0,
    this.intensita = '',
    this.forDate = '',
  });

  final String tipo;
  final String descrizione;
  final int durataMins;
  final String intensita;

  /// Data YYYY-MM-DD per cui è stato generato l'obiettivo.
  final String forDate;

  bool get hasContent => descrizione.isNotEmpty || tipo.isNotEmpty;

  /// Parsing dalla chiave `"allenamento"` del JSON unificato restituito da Gemini.
  factory AiCurrentAllenamentiModel.fromUnifiedJson(
    Map<String, dynamic> unifiedJson,
    String forDate,
  ) {
    final raw = unifiedJson['allenamento'];
    final m = raw is Map<String, dynamic> ? raw : <String, dynamic>{};
    return AiCurrentAllenamentiModel(
      tipo: m['tipo']?.toString() ?? '',
      descrizione: m['descrizione']?.toString() ?? '',
      durataMins: (m['durata_min'] as num?)?.toInt() ?? 0,
      intensita: m['intensita']?.toString() ?? '',
      forDate: forDate,
    );
  }

  factory AiCurrentAllenamentiModel.fromFirestore(Map<String, dynamic> data) {
    return AiCurrentAllenamentiModel(
      tipo: data['tipo']?.toString() ?? '',
      descrizione: data['descrizione']?.toString() ?? '',
      durataMins: (data['durata_min'] as num?)?.toInt() ?? 0,
      intensita: data['intensita']?.toString() ?? '',
      forDate: data['for_date']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'tipo': tipo,
      'descrizione': descrizione,
      'durata_min': durataMins,
      'intensita': intensita,
      'for_date': forDate,
      'updated_at': FieldValue.serverTimestamp(),
    };
  }
}
