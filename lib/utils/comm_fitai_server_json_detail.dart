/// Parsing messaggi errore REST / FastAPI (dettaglio in `detail` stringa o lista).
/// Separato dai flussi Garmin per non intaccare la logica di sync Garmin esistente.
String commFitaiServerDetailOrMessage(Map<String, dynamic>? data) {
  if (data == null) return '';
  final d = data['detail'];
  if (d is String && d.isNotEmpty) return d;
  if (d is List && d.isNotEmpty) {
    final parts = <String>[];
    for (final e in d) {
      if (e is Map && e['msg'] != null) {
        parts.add(e['msg'].toString());
      } else {
        parts.add(e.toString());
      }
    }
    return parts.where((s) => s.isNotEmpty).join('; ');
  }
  final m = data['message'];
  if (m is String && m.isNotEmpty) return m;
  return '';
}
