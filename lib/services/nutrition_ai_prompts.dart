/// Prompt condivisi per analisi nutrizionale (testo e foto).
class NutritionAiPrompts {
  NutritionAiPrompts._();

  static const String jsonSchema = '''
{
  "dish_name": "nome breve del pasto completo",
  "total_calories": numero,
  "estimated_portion_grams": numero,
  "protein_g": numero,
  "carbs_g": numero,
  "fat_g": numero,
  "fiber_g": numero,
  "sugar_g": numero,
  "longevity_score": numero da 1 a 10,
  "foods": [
    {
      "name": "stringa",
      "calories": numero,
      "portion": "stringa descrittiva (es. 1 scatoletta 80 g)",
      "grams": numero,
      "protein_g": numero,
      "carbs_g": numero,
      "fat_g": numero
    }
  ],
  "advice": "consiglio nutrizionale breve in italiano"
}''';

  static const String multiItemRules = '''
REGOLE OBBLIGATORIE:
- Se l'utente elenca più alimenti, analizza OGNI voce in "foods" e poi SOMMA calorie, macro e grammi nel totale del pasto.
- "estimated_portion_grams" = somma dei grammi di tutti gli alimenti (campo "grams" di ogni voce in "foods").
- "total_calories" e protein_g/carbs_g/fat_g devono essere la somma realistica di tutti gli alimenti, non di uno solo.
- Per prodotti confezionati o marchi (es. Rio Mare, Findus) usa porzioni standard reali (es. scatoletta tonno al naturale ≈ 80 g sgocciolato).
- Usa valori nutrizionali realistici da tabelle alimentari EU/italiane; non azzerare grassi o carboidrati se l'alimento li contiene.
- Se mancano quantità esplicite, stima porzioni tipiche italiane (es. insalata verde ≈ 80–120 g).
''';

  static String foodInfoFromText(String description) => '''
Analizza questo pasto descritto dall'utente: "$description".
Sei un nutrizionista esperto orientato alla longevità (stile Peter Attia).

$multiItemRules

Restituisci un JSON con questo schema esatto:
$jsonSchema

Rispondi solo con il JSON, niente testo aggiuntivo.
''';

  static const String nutritionFromImage = '''
Analizza questa foto di un piatto/cibo. Sei un nutrizionista orientato alla longevità (Peter Attia, Outlive).

$multiItemRules

Restituisci un JSON con questo schema esatto:
$jsonSchema

Stima le calorie e i macronutrienti in base al cibo visibile. Sii realistico.
''';
}
