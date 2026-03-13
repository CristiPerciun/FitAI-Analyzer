import 'package:fitai_analyzer/ui/theme/app_colors.dart';
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
      color: AppColors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.darkGreen.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: AppColors.darkGreen.withValues(alpha: 0.4),
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.darkGreen.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.restaurant,
                  color: AppColors.darkGreen,
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
                            color: AppColors.darkGreen,
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Analizza piatto – scatta foto per calorie e macronutrienti',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.darkGreen.withValues(alpha: 0.9),
                          ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.camera_alt,
                color: AppColors.darkGreen.withValues(alpha: 0.8),
                size: 24,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
