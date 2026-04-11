import 'package:fitai_analyzer/models/fitness_data.dart';
import 'package:fitai_analyzer/theme/app_card_theme.dart';
import 'package:fitai_analyzer/theme/app_theme.dart';
import 'package:fitai_analyzer/ui/widgets/garmin_activity_charts_section.dart';
import 'package:fitai_analyzer/utils/activity_utils.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Card dettaglio per attività Garmin (o dual con dati Garmin).
/// Mostra tutti i dati disponibili da FitnessData e garmin_raw.
class GarminActivityDetailCard extends StatelessWidget {
  const GarminActivityDetailCard({
    super.key,
    required this.activity,
    this.onTap,
  });

  final FitnessData activity;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cardTheme = theme.extension<AppCardTheme>()!;
    final type = activity.stravaActivityType;
    final name = activity.stravaActivityName ?? ActivityUtils.formatActivityType(type, fallback: 'Attività');
    final date = activity.date;
    final durationMin = activity.stravaElapsedMinutes;
    final distanceKm = activity.distanceKm ?? 0;
    final paceMinKm = distanceKm > 0
        ? (durationMin / 60 / distanceKm).toStringAsFixed(1)
        : null;
    final elevation = activity.stravaElevationGainM;
    final avgHr = activity.stravaAvgHeartrate;
    final maxHr = activity.stravaMaxHeartrate;
    final calories = activity.calories;
    final steps = activity.steps;
    final avgSpeed = activity.stravaAvgSpeedKmh;

    final raw = activity.garminRaw ?? {};
    final activityId = activity.garminActivityId ?? raw['activityId']?.toString();

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
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: AppColors.garminBlue.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        ActivityUtils.getActivityIcon(type),
                        size: 28,
                        color: AppColors.garminBlue,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
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
                          if (activityId != null) ...[
                            const SizedBox(height: 2),
                            Text(
                              'Garmin ID: $activityId',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: cardTheme.contentColorMuted,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (distanceKm > 0)
                      Text(
                        '${distanceKm.toStringAsFixed(2)} km',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: cardTheme.contentColor,
                        ),
                      ),
                  ],
                ),
                Divider(
                  height: 24,
                  color: cardTheme.contentColor.withValues(alpha: 0.3),
                ),
                Wrap(
                  spacing: 16,
                  runSpacing: 16,
                  children: [
                    _InfoColumn(
                      icon: Icons.timer_outlined,
                      label: 'Durata',
                      value: ActivityUtils.formatDurationMinutes(durationMin),
                    ),
                    if (distanceKm > 0)
                      _InfoColumn(
                        icon: Icons.straighten,
                        label: 'Distanza',
                        value: '${distanceKm.toStringAsFixed(2)} km',
                      ),
                    if (paceMinKm != null)
                      _InfoColumn(
                        icon: Icons.speed,
                        label: 'Pace',
                        value: '$paceMinKm min/km',
                      ),
                    if (avgSpeed != null && avgSpeed > 0)
                      _InfoColumn(
                        icon: Icons.speed,
                        label: 'Velocità',
                        value: '${avgSpeed.toStringAsFixed(1)} km/h',
                      ),
                    if (elevation != null && elevation > 0)
                      _InfoColumn(
                        icon: Icons.terrain,
                        label: 'Dislivello',
                        value: '${elevation.toInt()} m',
                      ),
                    if (calories != null && calories > 0)
                      _InfoColumn(
                        icon: Icons.local_fire_department,
                        label: 'Calorie',
                        value: '${calories.toInt()} kcal',
                      ),
                    if (steps != null && steps > 0)
                      _InfoColumn(
                        icon: Icons.directions_walk,
                        label: 'Passi',
                        value: steps.toInt().toString(),
                      ),
                  ],
                ),
                if (avgHr != null || maxHr != null) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Icon(
                        Icons.favorite,
                        color: AppColors.garminBlue,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        [
                          if (avgHr != null) '${avgHr.toInt()} bpm media',
                          if (maxHr != null) '${maxHr.toInt()} bpm max',
                        ].join(' • '),
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: cardTheme.contentColor,
                        ),
                      ),
                    ],
                  ),
                ],
                if (activity.source == 'dual') ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        Icons.link,
                        size: 16,
                        color: cardTheme.contentColorMuted,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Sincronizzato con Strava + Garmin',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: cardTheme.contentColorMuted,
                        ),
                      ),
                    ],
                  ),
                ],
                GarminActivityChartsSection(activity: activity),
                if (raw.isNotEmpty)
                  _ExtraSection(raw: raw, cardTheme: cardTheme, theme: theme),
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
    final cardTheme = theme.extension<AppCardTheme>()!;
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

/// Mostra campi extra da garmin_raw non già mappati nei getter.
class _ExtraSection extends StatelessWidget {
  const _ExtraSection({
    required this.raw,
    required this.cardTheme,
    required this.theme,
  });

  final Map<String, dynamic> raw;
  final AppCardTheme cardTheme;
  final ThemeData theme;

  static const _ignoredKeys = {
    'activityId', 'activityID', 'activityName', 'activityType', 'activityTypeKey',
    'startTime', 'startTimeGMT', 'startTimeLocal',
    'distance', 'duration', 'movingDuration',
    'averageHR', 'averageHeartRate', 'maxHR', 'maxHeartRate',
    'calories', 'elevationGain',
  };

  @override
  Widget build(BuildContext context) {
    final extras = <String, String>{};
    for (final e in raw.entries) {
      final key = e.key.toString();
      if (_ignoredKeys.contains(key)) continue;
      final v = e.value;
      if (v == null) continue;
      String display;
      if (v is num) {
        display = v is double ? v.toStringAsFixed(2) : v.toString();
      } else if (v is Map || v is List) {
        continue;
      } else {
        display = v.toString();
      }
      if (display.isNotEmpty) extras[key] = display;
    }
    if (extras.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        Text(
          'Altri dati Garmin',
          style: theme.textTheme.titleSmall?.copyWith(
            color: cardTheme.contentColorMuted,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        ...extras.entries.take(10).map((e) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 140,
                    child: Text(
                      _formatKey(e.key),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: cardTheme.contentColorMuted,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      e.value,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: cardTheme.contentColor,
                      ),
                    ),
                  ),
                ],
              ),
            )),
      ],
    );
  }

  static String _formatKey(String key) {
    final camel = key.replaceAllMapped(
      RegExp(r'([A-Z])'),
      (m) => ' ${m.group(1)!.toLowerCase()}',
    );
    return camel.trim().split(' ').map((w) => w.isEmpty ? w : w[0].toUpperCase() + w.substring(1)).join(' ');
  }
}
