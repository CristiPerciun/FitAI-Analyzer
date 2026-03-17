import 'package:fitai_analyzer/models/fitness_data.dart';
import 'package:fitai_analyzer/theme/app_card_theme.dart';
import 'package:fitai_analyzer/theme/app_theme.dart';
import 'package:fitai_analyzer/utils/activity_utils.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Card compatta per lista allenamenti: tipo, durata, orario, distanza, icona.
class CompactActivityCard extends StatelessWidget {
  const CompactActivityCard({
    super.key,
    required this.activity,
    this.onTap,
  });

  final FitnessData activity;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final type = activity.stravaActivityType;
    final durationMin = (activity.stravaElapsedMinutes).round();
    final startTime = DateFormat('HH:mm').format(activity.date);
    final distanceKm = activity.distanceKm;
    final hasDistance = distanceKm != null && distanceKm > 0;

    final cardTheme = Theme.of(context).extension<AppCardTheme>()!;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: cardTheme.gradientDecoration,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Builder(
                builder: (context) {
                  final isGarmin = activity.source == 'garmin';
                  final accentColor =
                      isGarmin ? AppColors.garminBlue : AppColors.stravaOrange;
                  return Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: accentColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      ActivityUtils.getActivityIcon(type),
                      color: accentColor,
                      size: 26,
                    ),
                  );
                },
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      ActivityUtils.formatActivityType(type),
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: cardTheme.contentColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.schedule,
                          size: 14,
                          color: cardTheme.contentColorMuted,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '$startTime • $durationMin min',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: cardTheme.contentColorMuted,
                          ),
                        ),
                        if (hasDistance) ...[
                          Text(
                            ' • ',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: cardTheme.contentColorMuted,
                            ),
                          ),
                          Text(
                            '${distanceKm.toStringAsFixed(2)} km',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: cardTheme.contentColor,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
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
