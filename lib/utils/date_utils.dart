/// Chiave calendario **locale** `YYYY-MM-DD` (NON UTC come `toIso8601String`).
/// [d] di default è l'istante corrente. Funzione canonica: usa questa invece di
/// ricostruire la stringa a mano o di copie private `_dateKey`.
String dateKey([DateTime? d]) {
  final n = d ?? DateTime.now();
  final y = n.year.toString().padLeft(4, '0');
  final m = n.month.toString().padLeft(2, '0');
  final day = n.day.toString().padLeft(2, '0');
  return '$y-$m-$day';
}

/// Solo la componente data (mezzanotte locale) di [d].
DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

/// Lunedì (ISO) della settimana che contiene [day] (weekday Dart: 1 = lun … 7 = dom).
DateTime mondayOfWeekContaining(DateTime day) {
  final d = dateOnly(day);
  return d.subtract(Duration(days: d.weekday - 1));
}

/// Lunedì della settimana a [weekOffset] settimane indietro rispetto a oggi
/// (0 = settimana corrente, 1 = precedente, ecc.).
DateTime weekMondayForOffset(int weekOffset) {
  final thisWeekMonday = mondayOfWeekContaining(DateTime.now());
  return thisWeekMonday.subtract(Duration(days: 7 * weekOffset));
}

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
  final list = <String>[dateKey(now)];
  for (var i = 1; i <= 5; i++) {
    list.add(dateKey(now.subtract(Duration(days: i))));
  }
  return list;
}
