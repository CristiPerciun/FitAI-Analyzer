/// Costanti e helper per pasti (Colazione, Pranzo, Cena).
/// Usato da providers, alimentazione_screen, meal_model.
class MealConstants {
  MealConstants._();

  /// Tipi pasto supportati.
  static const List<String> mealTypes = ['Colazione', 'Pranzo', 'Cena'];

  /// Label lowercase per UI (colazione, pranzo, cena).
  static const List<String> mealLabels = ['colazione', 'pranzo', 'cena'];

  /// Infers meal type from dish name prefix.
  /// Es: "Colazione: Toast" → "Colazione", "Pranzo: Pasta" → "Pranzo".
  static String inferMealType(String dishName) {
    final d = dishName.toLowerCase();
    if (d.startsWith('colazione')) return 'Colazione';
    if (d.startsWith('pranzo')) return 'Pranzo';
    if (d.startsWith('cena')) return 'Cena';
    return 'Pranzo';
  }

  /// Capitalizza label (colazione → Colazione).
  static String toMealType(String label) {
    if (label.isEmpty) return '';
    return label.substring(0, 1).toUpperCase() + label.substring(1);
  }
}
