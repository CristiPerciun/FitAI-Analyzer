import 'dart:typed_data';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:fitai_analyzer/providers/auth_notifier.dart';
import 'package:fitai_analyzer/services/gemini_api_key_service.dart';
import 'package:fitai_analyzer/services/gemini_service.dart';
import 'package:fitai_analyzer/services/nutrition_service.dart';
import 'package:fitai_analyzer/ui/widgets/error_dialog.dart';
import 'package:fitai_analyzer/ui/widgets/gemini_api_key_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

/// Pagina dedicata all'alimentazione.
/// Qui andranno tutte le funzionalità: analizza piatto, storico pasti, ecc.
class AlimentazioneScreen extends ConsumerWidget {
  const AlimentazioneScreen({super.key});

  Future<void> _onAnalisiPiatto(
    BuildContext context,
    WidgetRef ref, {
    String? mealLabel,
  }) async {
    var uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      // Su iOS dopo reload la sessione può non essere ancora ripristinata.
      // Se l'utente va direttamente su Alimentazione senza Strava, non ha mai fatto login.
      // In entrambi i casi: tenta login anonimo (come per Strava).
      try {
        await ref.read(authNotifierProvider.notifier).signInAnonymously();
        uid = FirebaseAuth.instance.currentUser?.uid;
      } catch (e) {
        if (context.mounted) {
          showErrorDialog(
            context,
            'Impossibile autenticarsi. Riprova. ($e)',
          );
        }
        return;
      }
      if (uid == null && context.mounted) {
        showErrorDialog(context, 'Utente non autenticato.');
        return;
      }
    }

    final apiKeyService = ref.read(geminiApiKeyServiceProvider);
    if (!await apiKeyService.hasValidKey()) {
      if (!context.mounted) return;
      final saved = await showGeminiApiKeyDialog(context, ref);
      if (!saved || !context.mounted) return;
    }

    final picker = ImagePicker();
    final xFile = await picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 85,
    );
    if (xFile == null || !context.mounted) return;

    final bytes = await xFile.readAsBytes();
    final mimeType = xFile.path.toLowerCase().endsWith('.png')
        ? 'image/png'
        : 'image/jpeg';

    if (!context.mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const AlertDialog(
        content: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 16),
            Text('Analisi nutrizione in corso...'),
          ],
        ),
      ),
    );

    try {
      final gemini = ref.read(geminiServiceProvider);
      final nutrition = ref.read(nutritionServiceProvider);
      final result = await gemini.analyzeNutritionFromImage(
        Uint8List.fromList(bytes),
        mimeType: mimeType,
      );

      if (context.mounted) Navigator.of(context).pop();

      if (result.containsKey('error')) {
        if (context.mounted) showErrorDialog(context, result['error'] ?? 'Errore');
        return;
      }

      await nutrition.saveToFirestore(uid!, result, mealLabel: mealLabel);

      if (context.mounted) {
        _showNutritionDialog(context, result);
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.of(context).pop();
        showErrorDialog(context, e.toString());
      }
    }
  }

  void _showNutritionDialog(BuildContext context, Map<String, dynamic> nut) {
    final cal = nut['total_calories'] ?? nut['calories'] ?? 0;
    final p = nut['protein_g'] ?? nut['protein'] ?? 0;
    final c = nut['carbs_g'] ?? nut['carbs'] ?? 0;
    final f = nut['fat_g'] ?? nut['fat'] ?? 0;
    final fiber = nut['fiber_g'] ?? nut['fiber'] ?? 0;
    final sugar = nut['sugar_g'] ?? nut['sugar'] ?? 0;
    final advice = nut['advice'] ?? '';
    final foods = nut['foods'] as List<dynamic>? ?? [];

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Analisi nutrizione'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${(cal as num).round()} kcal',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 12,
                runSpacing: 4,
                children: [
                  _Chip(label: 'Proteine', value: '${(p as num).round()}g'),
                  _Chip(label: 'Carbs', value: '${(c as num).round()}g'),
                  _Chip(label: 'Grassi', value: '${(f as num).round()}g'),
                  if (fiber > 0) _Chip(label: 'Fibre', value: '${(fiber as num).round()}g'),
                  if (sugar > 0) _Chip(label: 'Zuccheri', value: '${(sugar as num).round()}g'),
                ],
              ),
              if (foods.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(
                  'Alimenti',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 4),
                ...foods.take(8).map((e) {
                  final m = e is Map ? e as Map<String, dynamic> : <String, dynamic>{};
                  final name = m['name'] ?? '?';
                  final cals = m['calories'];
                  final portion = m['portion'];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      '• $name${cals != null ? ' (${(cals as num).round()} kcal)' : ''}${portion != null ? ' - $portion' : ''}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  );
                }),
              ],
              if (advice.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(
                  'Consiglio',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 4),
                Text(
                  advice,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Chiudi'),
          ),
        ],
      ),
    );
  }

  void _showAggiungiPastoSheet(
    BuildContext context,
    WidgetRef ref,
    String mealLabel,
  ) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Aggiungi $mealLabel',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF2E7D32),
                    ),
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: () {
                  Navigator.of(ctx).pop();
                  _onAnalisiPiatto(context, ref, mealLabel: mealLabel);
                },
                icon: const Icon(Icons.camera_alt),
                label: const Text('Con la foto'),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF2E7D32),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () {
                  Navigator.of(ctx).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Inserimento manuale $mealLabel (in arrivo)'),
                    ),
                  );
                },
                icon: const Icon(Icons.edit),
                label: const Text('Manualmente'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF2E7D32),
                  side: const BorderSide(color: Color(0xFF2E7D32)),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Alimentazione'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/'),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.key),
            tooltip: 'Chiave API Gemini',
            onPressed: () async {
              await showGeminiApiKeyDialog(context, ref);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Chiave salvata. Usa "Con la foto" per analizzare.'),
                  ),
                );
              }
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _MealCard(
              label: 'Colazione',
              onTap: () => _showAggiungiPastoSheet(context, ref, 'colazione'),
            ),
            const SizedBox(height: 16),
            _MealCard(
              label: 'Pranzo',
              onTap: () => _showAggiungiPastoSheet(context, ref, 'pranzo'),
            ),
            const SizedBox(height: 16),
            _MealCard(
              label: 'Cena',
              onTap: () => _showAggiungiPastoSheet(context, ref, 'cena'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Card pasto (Colazione/Pranzo/Cena) con stile uguale alle card della pagina principale.
class _MealCard extends StatelessWidget {
  const _MealCard({
    required this.label,
    required this.onTap,
  });

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFF2E7D32).withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: const Color(0xFF2E7D32).withValues(alpha: 0.4),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: const Color(0xFF2E7D32),
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF2E7D32).withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.add,
                  color: Color(0xFF2E7D32),
                  size: 24,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Chip(
      label: Text('$label: $value'),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }
}
