import 'package:fitai_analyzer/models/fitness_data.dart';
import 'package:fitai_analyzer/theme/app_card_theme.dart';
import 'package:fitai_analyzer/theme/app_theme.dart';
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

  static IconData _getIcon(String type) {
    final t = type.toLowerCase();
    if (t.contains('run') || t.contains('trail')) return Icons.directions_run;
    if (t.contains('ride') || t.contains('bike') || t.contains('cycle')) {
      return Icons.directions_bike;
    }
    if (t.contains('swim')) return Icons.pool;
    if (t.contains('walk') || t.contains('hike')) return Icons.directions_walk;
    if (t.contains('workout') || t.contains('weight') || t.contains('gym')) {
      return Icons.fitness_center;
    }
    return Icons.fitness_center;
  }

  static String _formatType(String type) {
    final t = type.toLowerCase();
    if (t.contains('run')) return 'Run';
    if (t.contains('ride') || t.contains('bike') || t.contains('cycle')) {
      return 'Ride';
    }
    if (t.contains('swim')) return 'Swim';
    if (t.contains('walk')) return 'Walk';
    if (t.contains('hike')) return 'Hike';
    if (t.contains('workout') || t.contains('weight') || t.contains('gym')) {
      return 'Workout';
    }
    return type.isNotEmpty ? type : 'Workout';
  }

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
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.stravaOrange.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  _getIcon(type),
                  color: AppColors.stravaOrange,
                  size: 26,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _formatType(type),
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
