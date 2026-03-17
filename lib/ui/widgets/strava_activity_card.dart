import 'package:fitai_analyzer/services/strava_service.dart';
import 'package:fitai_analyzer/theme/app_card_theme.dart';
import 'package:fitai_analyzer/theme/app_theme.dart';
import 'package:fitai_analyzer/utils/activity_utils.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class StravaActivityCard extends StatelessWidget {
  const StravaActivityCard({
    super.key,
    required this.activity,
    this.onTap,
  });

  final StravaActivity activity;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final date = DateTime.tryParse(activity.startDate) ?? DateTime.now();
    final paceMinKm = activity.distance > 0
        ? (activity.movingTime / 60 / (activity.distance / 1000))
            .toStringAsFixed(1)
        : '—';

    final cardTheme = Theme.of(context).extension<AppCardTheme>()!;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 8),
      decoration: cardTheme.gradientDecoration,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    ActivityUtils.getActivityIcon(activity.sportType),
                    size: 32,
                    color: AppColors.stravaOrange,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          activity.name,
                          style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: cardTheme.contentColor,
                              ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          DateFormat('dd MMM yyyy • HH:mm').format(date),
                          style: theme.textTheme.bodySmall?.copyWith(
                                color: cardTheme.contentColorMuted,
                              ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    '${(activity.distance / 1000).toStringAsFixed(2)} km',
                    style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: cardTheme.contentColor,
                        ),
                  ),
                ],
              ),
              Divider(height: 24, color: cardTheme.contentColor.withValues(alpha: 0.3)),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _InfoColumn(
                    icon: Icons.timer_outlined,
                    label: 'Durata',
                    value: ActivityUtils.formatDurationSeconds(activity.movingTime),
                  ),
                  _InfoColumn(
                    icon: Icons.speed,
                    label: 'Pace',
                    value: '$paceMinKm min/km',
                  ),
                  _InfoColumn(
                    icon: Icons.terrain,
                    label: '↑ Disl.',
                    value: '${activity.elevationGain.toInt()} m',
                  ),
                ],
              ),
              if (activity.avgHeartrate != null) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(Icons.favorite, color: AppColors.stravaOrange, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      '${activity.avgHeartrate!.toInt()} bpm'
                      '${activity.maxHeartrate != null ? ' (max ${activity.maxHeartrate!.toInt()})' : ''}',
                      style: theme.textTheme.bodyMedium?.copyWith(
                            color: cardTheme.contentColor,
                          ),
                    ),
                  ],
                ),
              ],
              if (activity.deviceName != null && activity.deviceName!.isNotEmpty) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.watch, size: 16, color: cardTheme.contentColorMuted),
                    const SizedBox(width: 8),
                    Text(
                      'Registrato con ${activity.deviceName}',
                      style: theme.textTheme.bodySmall?.copyWith(
                            color: cardTheme.contentColorMuted,
                          ),
                    ),
                  ],
                ),
              ],
              if (activity.calories != null) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.local_fire_department,
                        size: 18, color: AppColors.stravaOrange),
                    const SizedBox(width: 8),
                    Text(
                      '${activity.calories!.toInt()} kcal',
                      style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: cardTheme.contentColor,
                          ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    ),
    );
  }
}

class _InfoColumn extends StatelessWidget {
  const _InfoColumn({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cardTheme = Theme.of(context).extension<AppCardTheme>()!;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 20, color: cardTheme.contentColorMuted),
        const SizedBox(height: 4),
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
                color: cardTheme.contentColorMuted,
              ),
        ),
        Text(
          value,
          style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: cardTheme.contentColor,
              ),
        ),
      ],
    );
  }
}
