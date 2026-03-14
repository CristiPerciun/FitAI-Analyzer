import 'package:fitai_analyzer/theme/app_card_theme.dart';
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
    final cardTheme = Theme.of(context).extension<AppCardTheme>()!;

    return Container(
      decoration: cardTheme.gradientDecoration,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: cardTheme.contentColor.withValues(alpha: 0.3),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.restaurant,
                    color: cardTheme.contentColor,
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
                              color: cardTheme.contentColor,
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Analizza piatto – scatta foto per calorie e macronutrienti',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: cardTheme.contentColorMuted,
                            ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.camera_alt,
                  color: cardTheme.contentColorMuted,
                  size: 24,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
