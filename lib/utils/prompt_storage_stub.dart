import 'package:flutter/foundation.dart';

/// Stub per web: salvataggio prompt non supportato (sandbox browser).
Future<void> savePromptToFile(String prompt) async {
  if (kDebugMode) {
    debugPrint('Prompt storage: non supportato su web. Esegui su Windows/Android per salvare in lib/utils/prompt/');
  }
}
