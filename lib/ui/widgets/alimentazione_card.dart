import 'package:flutter/material.dart';

/// Card Alimentazione usata in auth_selection e dashboard.
/// Layout: icona sinistra, titolo/sottotitolo, icona camera destra.
class AlimentazioneCard extends StatelessWidget {
  const AlimentazioneCard({
    required this.onTap,
    super.key,
  });

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
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF2E7D32).withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.restaurant,
                  color: Color(0xFF2E7D32),
                  size: 32,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Alimentazione',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            color: const Color(0xFF2E7D32),
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Analizza piatto – scatta foto per calorie e macronutrienti',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: const Color(0xFF2E7D32).withValues(alpha: 0.9),
                          ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.camera_alt,
                color: const Color(0xFF2E7D32).withValues(alpha: 0.8),
                size: 24,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
