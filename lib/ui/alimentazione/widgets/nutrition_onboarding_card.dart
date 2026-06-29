import 'package:fitai_analyzer/ui/widgets/design/design.dart';
import 'package:flutter/material.dart';

/// Card CTA mostrata quando l'obiettivo mangiare non è ancora configurato.
class NutritionOnboardingCard extends StatelessWidget {
  const NutritionOnboardingCard({super.key, required this.onConfigure});

  final VoidCallback onConfigure;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return FitSoftCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const FitIconBadge(icon: Icons.restaurant_menu),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Obiettivo Mangiare',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: cs.onSurface,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Imposta preferenze, obiettivo nutrizionale e target calorico. Poi vedrai qui obiettivo giornaliero, calorie assunte e kcal rimanenti.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: cs.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: onConfigure,
            child: const Text('Configura obiettivo mangiare'),
          ),
        ],
      ),
    );
  }
}
