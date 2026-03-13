import 'package:fitai_analyzer/services/strava_service.dart';
import 'package:fitai_analyzer/ui/theme/app_colors.dart';
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

  static String _formatDuration(int seconds) {
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    return h > 0 ? '$h h $m min' : '$m min';
  }

  static IconData _getIcon(String type) {
    final t = type.toLowerCase();
    if (t.contains('run') || t.contains('trail')) return Icons.directions_run;
    if (t.contains('ride') || t.contains('bike') || t.contains('cycle')) {
      return Icons.directions_bike;
    }
    if (t.contains('swim')) return Icons.pool;
    if (t.contains('walk') || t.contains('hike')) return Icons.directions_walk;
    return Icons.fitness_center;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final date = DateTime.tryParse(activity.startDate) ?? DateTime.now();
    final paceMinKm = activity.distance > 0
        ? (activity.movingTime / 60 / (activity.distance / 1000))
            .toStringAsFixed(1)
        : '—';

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 8),
      elevation: 2,
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
                    _getIcon(activity.sportType),
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
                              ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          DateFormat('dd MMM yyyy • HH:mm').format(date),
                          style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    '${(activity.distance / 1000).toStringAsFixed(2)} km',
                    style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.primary,
                        ),
                  ),
                ],
              ),
              const Divider(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _InfoColumn(
                    icon: Icons.timer_outlined,
                    label: 'Durata',
                    value: _formatDuration(activity.movingTime),
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
                    Icon(Icons.favorite, color: theme.colorScheme.error, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      '${activity.avgHeartrate!.toInt()} bpm'
                      '${activity.maxHeartrate != null ? ' (max ${activity.maxHeartrate!.toInt()})' : ''}',
                      style: theme.textTheme.bodyMedium,
                    ),
                  ],
                ),
              ],
              if (activity.deviceName != null && activity.deviceName!.isNotEmpty) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.watch, size: 16, color: theme.colorScheme.outline),
                    const SizedBox(width: 8),
                    Text(
                      'Registrato con ${activity.deviceName}',
                      style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
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
                        size: 18, color: theme.colorScheme.tertiary),
                    const SizedBox(width: 8),
                    Text(
                      '${activity.calories!.toInt()} kcal',
                      style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ],
                ),
              ],
            ],
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
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 20, color: theme.colorScheme.primary),
        const SizedBox(height: 4),
        Text(label, style: theme.textTheme.labelSmall),
        Text(
          value,
          style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
      ],
    );
  }
}
