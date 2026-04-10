import 'package:fitai_analyzer/services/ai_backend_preference_service.dart'
    show AiBackend, aiBackendPreferenceServiceProvider;
import 'package:fitai_analyzer/services/gemini_api_key_service.dart';
import 'package:fitai_analyzer/ui/widgets/deepseek_api_key_dialog.dart';
import 'package:fitai_analyzer/ui/widgets/gemini_api_key_dialog.dart';
import 'package:fitai_analyzer/ui/widgets/openrouter_api_key_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Se il backend attivo non ha chiave, apre il dialog appropriato.
Future<bool> ensureActiveAiBackendHasKey(
  BuildContext context,
  WidgetRef ref,
) async {
  final prefs = ref.read(aiBackendPreferenceServiceProvider);
  final gemini = ref.read(geminiApiKeyServiceProvider);
  if (await prefs.isActiveBackendConfigured(gemini)) return true;

  final b = await prefs.getBackend();
  if (!context.mounted) return false;
  if (b == AiBackend.deepseek) {
    final ok = await showDeepSeekApiKeyDialog(context, ref);
    return ok && await prefs.hasValidDeepSeekKey();
  }
  if (b == AiBackend.openrouter) {
    final ok = await showOpenRouterApiKeyDialog(context, ref);
    return ok && await prefs.hasValidOpenRouterKey();
  }
  final saved = await showGeminiApiKeyDialog(context, ref);
  return saved && await gemini.hasValidKey();
}
