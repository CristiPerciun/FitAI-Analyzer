import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// Salva il prompt master in locale per demo.
/// Solo su Windows. Prova in ordine: lib/utils/prompt, Downloads/prompt, app documents/prompt.
Future<void> savePromptToFile(String prompt) async {
  if (!Platform.isWindows) return;

  final now = DateTime.now();
  final filename = 'prompt_${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day}_'
      '${now.hour.toString().padLeft(2, '0')}-${now.minute.toString().padLeft(2, '0')}-'
      '${now.second.toString().padLeft(2, '0')}-${now.millisecond.toString().padLeft(3, '0')}.txt';

  bool saved = await _saveToPath(prompt, filename, '${Directory.current.path}/lib/utils/prompt');
  if (!saved) {
    final downloads = await getDownloadsDirectory();
    if (downloads != null) {
      saved = await _saveToPath(prompt, filename, '${downloads.path}/FitAI_prompt');
    }
  }
  if (!saved) {
    final dir = await getApplicationDocumentsDirectory();
    saved = await _saveToPath(prompt, filename, '${dir.path}/prompt');
  }
  if (!saved && kDebugMode) {
    debugPrint('savePromptToFile: nessun percorso disponibile');
  }
}

Future<bool> _saveToPath(String prompt, String filename, String dirPath) async {
  try {
    final promptDir = Directory(dirPath);
    if (!await promptDir.exists()) {
      await promptDir.create(recursive: true);
    }
    final file = File('$dirPath/$filename');
    await file.writeAsString(prompt, encoding: utf8);
    if (kDebugMode) {
      debugPrint('Prompt salvato: ${file.path}');
    }
    return true;
  } catch (e, st) {
    if (kDebugMode) {
      debugPrint('savePromptToFile ($dirPath) fallito: $e\n$st');
    }
    return false;
  }
}
