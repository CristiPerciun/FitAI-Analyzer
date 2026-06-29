// Helper di parsing per il JSON nutrizionale prodotto dall'AI (Gemini/DeepSeek/
// OpenRouter). Tollerano varianti di tipo perché la risposta AI non è
// garantita schema-stabile.

/// Estrae un consiglio testuale da un valore eterogeneo (`String`, `null`, ecc.).
String nutritionAdviceString(dynamic v) {
  if (v == null) return '';
  if (v is String) return v;
  return v.toString();
}

/// Estrae la lista grezza degli alimenti (mappe) preservando i campi originali,
/// usata dalla schermata di revisione pasto.
List<dynamic> nutritionFoodsList(dynamic v) {
  if (v is List) return List<dynamic>.from(v);
  return [];
}
