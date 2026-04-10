import 'package:fitai_analyzer/providers/auth_notifier.dart';
import 'package:fitai_analyzer/providers/providers.dart';
import 'package:fitai_analyzer/services/ai_backend_preference_service.dart';
import 'package:fitai_analyzer/services/user_ai_settings_sync_service.dart';
import 'package:fitai_analyzer/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Dialog per inserire la chiave API DeepSeek (salvata in Secure Storage).
Future<bool> showDeepSeekApiKeyDialog(BuildContext context, WidgetRef ref) async {
  final controller = TextEditingController();
  final prefs = ref.read(aiBackendPreferenceServiceProvider);

  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => AlertDialog(
      title: const Text('Chiave API DeepSeek'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Inserisci la chiave API DeepSeek. Con account collegato viene sincronizzata '
            'anche su altri dispositivi (Firebase).',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: controller,
            decoration: const InputDecoration(
              labelText: 'API Key',
              border: OutlineInputBorder(),
            ),
            obscureText: true,
            autocorrect: false,
          ),
          const SizedBox(height: 8),
          Text(
            'Ottienila da platform.deepseek.com/api_keys',
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
            final uid = ref.read(authNotifierProvider).user?.uid;
            if (uid != null) {
              await ref
                  .read(userAiSettingsSyncServiceProvider)
                  .saveDeepSeekKeyLocalAndCloud(uid, key);
            } else {
              await prefs.saveDeepSeekKey(key);
            }
            invalidateAiRouting(ref);
            if (ctx.mounted) Navigator.of(ctx).pop(true);
          },
          child: const Text('Salva'),
        ),
      ],
    ),
  );
  return result ?? false;
}
