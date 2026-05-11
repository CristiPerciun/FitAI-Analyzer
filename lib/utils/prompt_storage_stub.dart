import 'package:flutter/foundation.dart';

/// Stub per web: salvataggio prompt non supportato (sandbox browser).
Future<void> savePromptToFile(
  String prompt, {
  String promptName = 'main',
  String? folderName,
}) async {
  if (kDebugMode) {
    debugPrint('Prompt storage: non supportato su web. Esegui su Windows per salvare in lib/utils/prompt/');
  }
}
