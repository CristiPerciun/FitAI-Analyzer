/// Costanti e helper per pasti (Colazione, Pranzo, Cena, Spuntino).
/// Usato da providers, alimentazione_screen, meal_model, meal_capture_flow.
class MealConstants {
  MealConstants._();

  /// Tipi pasto supportati (capitalizzati).
  /// Lo Spuntino raccoglie pasti consumati fuori dalle fasce orarie principali.
  static const List<String> mealTypes = ['Colazione', 'Pranzo', 'Cena', 'Spuntino'];

  /// Label lowercase per UI (colazione, pranzo, cena, spuntino).
  static const List<String> mealLabels = ['colazione', 'pranzo', 'cena', 'spuntino'];

  /// Infers meal type from dish name prefix.
  /// Es: "Colazione: Toast" → "Colazione", "Spuntino: Yogurt" → "Spuntino".
  static String inferMealType(String dishName) {
    final d = dishName.toLowerCase();
    if (d.startsWith('colazione')) return 'Colazione';
    if (d.startsWith('pranzo')) return 'Pranzo';
    if (d.startsWith('cena')) return 'Cena';
    if (d.startsWith('spuntino')) return 'Spuntino';
    return 'Pranzo';
  }

  /// Capitalizza label (colazione → Colazione).
  static String toMealType(String label) {
    if (label.isEmpty) return '';
    return label.substring(0, 1).toUpperCase() + label.substring(1);
  }

  /// Sceglie il pasto adatto all'ora corrente.
  /// Fasce: colazione 5:00-10:30, pranzo 11:30-15:00, cena 18:30-22:30,
  /// tutto il resto è classificato come spuntino.
  /// Restituisce la label lowercase ('colazione' | 'pranzo' | 'cena' | 'spuntino').
  static String mealLabelForTime(DateTime now) {
    final minutes = now.hour * 60 + now.minute;
    const colazioneStart = 5 * 60;
    const colazioneEnd = 10 * 60 + 30;
    const pranzoStart = 11 * 60 + 30;
    const pranzoEnd = 15 * 60;
    const cenaStart = 18 * 60 + 30;
    const cenaEnd = 22 * 60 + 30;

    if (minutes >= colazioneStart && minutes < colazioneEnd) return 'colazione';
    if (minutes >= pranzoStart && minutes < pranzoEnd) return 'pranzo';
    if (minutes >= cenaStart && minutes < cenaEnd) return 'cena';
    return 'spuntino';
  }
}
