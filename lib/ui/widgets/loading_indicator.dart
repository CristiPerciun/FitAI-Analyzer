import 'package:flutter/material.dart';

/// Indicatore di caricamento condiviso.
/// Usato da auth_gateway, home_screen, dashboard_screen, alimentazione_screen, ecc.
class LoadingIndicator extends StatelessWidget {
  const LoadingIndicator({
    super.key,
    this.message,
    this.size,
  });

  /// Messaggio opzionale accanto allo spinner.
  final String? message;

  /// Dimensione spinner (default 36).
  final double? size;

  @override
  Widget build(BuildContext context) {
    final child = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: size ?? 36,
          height: size ?? 36,
          child: const CircularProgressIndicator(strokeWidth: 2),
        ),
        if (message != null && message!.isNotEmpty) ...[
          const SizedBox(width: 16),
          Text(message!, style: Theme.of(context).textTheme.bodyMedium),
        ],
      ],
    );
    return Center(child: child);
  }
}

/// Schermata intera con loading (es. durante auth check).
class LoadingScreen extends StatelessWidget {
  const LoadingScreen({
    super.key,
    this.message,
  });

  final String? message;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: LoadingIndicator(message: message),
    );
  }
}
