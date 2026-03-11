import 'package:flutter/material.dart';

/// Mostra un AlertDialog descrittivo con il messaggio di errore completo.
Future<void> showErrorDialog(BuildContext context, String message) async {
  if (!context.mounted) return;
  await showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      icon: Icon(Icons.error_outline, color: Theme.of(context).colorScheme.error, size: 48),
      title: const Text('Errore'),
      content: SingleChildScrollView(
        child: SelectableText(
          message,
          style: const TextStyle(fontSize: 14),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('OK'),
        ),
      ],
    ),
  );
}
