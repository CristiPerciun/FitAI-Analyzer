import 'package:fitai_analyzer/services/gemini_api_key_service.dart';
import 'package:fitai_analyzer/services/gemini_service.dart';
import 'package:fitai_analyzer/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Dialog per inserire la chiave API Gemini.
/// Usato su iOS quando .env non è disponibile (chiave solo in locale).
Future<bool> showGeminiApiKeyDialog(BuildContext context, WidgetRef ref) async {
  final controller = TextEditingController();
  final apiKeyService = ref.read(geminiApiKeyServiceProvider);

  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => AlertDialog(
      title: const Text('Chiave API Gemini'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Inserisci la tua chiave API Gemini per usare l\'analisi nutrizionale da foto.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: controller,
            decoration: const InputDecoration(
              labelText: 'API Key',
              hintText: 'AIza...',
              border: OutlineInputBorder(),
            ),
            obscureText: true,
            autocorrect: false,
          ),
          const SizedBox(height: 8),
          Text(
            'Ottienila da aistudio.google.com/apikey',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.textMuted,
                ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: const Text('Annulla'),
        ),
        FilledButton(
          onPressed: () async {
            final key = controller.text.trim();
            if (key.isEmpty) return;
            await apiKeyService.saveKey(key);
            ref.invalidate(geminiServiceProvider);
            if (ctx.mounted) Navigator.of(ctx).pop(true);
          },
          child: const Text('Salva'),
        ),
      ],
    ),
  );
  return result ?? false;
}
