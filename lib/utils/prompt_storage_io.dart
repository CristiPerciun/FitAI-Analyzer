import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// Salva il prompt master in locale (cartella prompt/) per demo.
/// Non crea file su iOS (come richiesto).
Future<void> savePromptToFile(String prompt) async {
  if (Platform.isIOS) return;

  try {
    final dir = await getApplicationDocumentsDirectory();
    final promptDir = Directory('${dir.path}/prompt');
    if (!await promptDir.exists()) {
      await promptDir.create(recursive: true);
    }

    final now = DateTime.now();
    final filename = 'prompt_${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day}_'
        '${now.hour.toString().padLeft(2, '0')}-${now.minute.toString().padLeft(2, '0')}-'
        '${now.second.toString().padLeft(2, '0')}.txt';
    final file = File('${promptDir.path}/$filename');
    await file.writeAsString(prompt, encoding: utf8);
  } catch (_) {}
}
