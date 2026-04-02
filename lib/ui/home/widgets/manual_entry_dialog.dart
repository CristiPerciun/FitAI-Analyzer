import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fitai_analyzer/services/gemini_service.dart';

class ManualEntryDialog extends ConsumerStatefulWidget {
  const ManualEntryDialog({super.key});

  @override
  ConsumerState<ManualEntryDialog> createState() => _ManualEntryDialogState();
}

class _ManualEntryDialogState extends ConsumerState<ManualEntryDialog> {
  final TextEditingController _controller = TextEditingController();
  bool _isLoading = false;

  // Funzione per gestire l'analisi con l'IA
  Future<void> _analyzeInput() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    setState(() => _isLoading = true);

    try {
      final geminiService = ref.read(geminiServiceProvider);
      
      // Chiamata alla funzione che abbiamo aggiornato nel GeminiService
      final result = await geminiService.getFoodInfoFromText(text);

      if (mounted) {
        if (result.containsKey('error')) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Errore: ${result['error']}")),
          );
        } else {
          // Restituiamo il Map con i dati nutrizionali alla pagina che ha aperto il dialog
          Navigator.pop(context, result);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Errore durante l'analisi: $e")),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text("Cosa hai mangiato?", 
        style: TextStyle(fontWeight: FontWeight.bold)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _controller,
            maxLines: 3,
            enabled: !_isLoading,
            decoration: InputDecoration(
              hintText: "Esempio: 100g di pasta al pomodoro e una mela",
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
          if (_isLoading) ...[
            const SizedBox(height: 20),
            const CircularProgressIndicator(),
            const SizedBox(height: 10),
            const Text("L'IA sta analizzando...", style: TextStyle(fontSize: 12, color: Colors.grey)),
          ]
        ],
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.pop(context),
          child: const Text("Annulla", style: TextStyle(color: Colors.grey)),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _analyzeInput,
          style: ElevatedButton.styleFrom(
            backgroundColor: Theme.of(context).primaryColor,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            padding: const EdgeInsets.symmetric(horizontal: 20),
          ),
          child: const Text("Analizza", style: TextStyle(color: Colors.white)),
        ),
      ],
    );
  }
}