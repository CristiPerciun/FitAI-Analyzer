/// Formatta una data YYYY-MM-DD per visualizzazione (gg/mm).
String formatDateForDisplay(String yyyyMmDd) {
  final parts = yyyyMmDd.split('-');
  if (parts.length != 3) return yyyyMmDd;
  return '${parts[2]}/${parts[1]}';
}

/// Sentinel per "Tutti" (mostra tutte le date).
const String dateFilterAll = '__ALL__';

/// Ultimi 6 giorni: oggi + 5 giorni indietro, in ordine.
List<String> last6Days() {
  final now = DateTime.now();
  final today = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  final list = <String>[today];
  for (var i = 1; i <= 5; i++) {
    final d = now.subtract(Duration(days: i));
    list.add('${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}');
  }
  return list;
}
