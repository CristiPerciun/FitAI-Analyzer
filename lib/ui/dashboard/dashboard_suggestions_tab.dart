import 'package:fitai_analyzer/models/fitness_data.dart';
import 'package:fitai_analyzer/providers/dashboard_activity_providers.dart';
import 'package:fitai_analyzer/providers/data_sync_notifier.dart';
import 'package:fitai_analyzer/theme/app_card_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Secondo tab Allenamenti: riepilogo giornata e spazio per suggerimenti pratici.
class DashboardSuggestionsTab extends ConsumerWidget {
  const DashboardSuggestionsTab({
    super.key,
    required this.onAnalisiAiTap,
  });

  final VoidCallback onAnalisiAiTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final byDate = ref.watch(activitiesByDateProvider);
    final now = DateTime.now();
    final todayKey = activityDateKey(DateTime(now.year, now.month, now.day));
    final todayActs = byDate[todayKey] ?? [];
    final kcalToday = todayActs.fold<double>(
      0,
      (s, a) => s + (a.calories ?? 0),
    );

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(activitiesStreamProvider);
      },
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          Text(
            formatDateForDisplay(todayKey),
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Allenamenti e focus della giornata',
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(
                color: theme.colorScheme.outline.withValues(alpha: 0.2),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.local_fire_department_outlined,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Oggi in movimento',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    todayActs.isEmpty
                        ? 'Nessuna attività registrata per oggi. Collega Strava o attendi la sync Garmin.'
                        : '${todayActs.length} attività · ${kcalToday.toStringAsFixed(0)} kcal bruciate (stima da dispositivo / Strava)',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  if (todayActs.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    ...todayActs.take(4).map((a) => _TodayActivityRow(data: a)),
                    if (todayActs.length > 4)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          '+ altre ${todayActs.length - 4} nel tab Progressi',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          _SuggestionTile(
            icon: Icons.water_drop_outlined,
            title: 'Idratazione',
            body:
                'Dopo sessioni con sudorazione, recupera liquidi a piccoli sorsi nel corso della serata.',
          ),
          const SizedBox(height: 12),
          _SuggestionTile(
            icon: Icons.nights_stay_outlined,
            title: 'Recupero',
            body:
                'Se oggi hai spinto forte, preferisci sonno regolare e una seduta leggera domani oppure riposo attivo (camminata).',
          ),
          const SizedBox(height: 12),
          _SuggestionTile(
            icon: Icons.coffee_outlined,
            title: 'Consistenza',
            body:
                'Due o tre brevi uscite a settimana battono un solo allenamento lungo: mantieni il ritmo che sai sostenere.',
          ),
          const SizedBox(height: 20),
          Container(
            decoration:
                theme.extension<AppCardTheme>()?.gradientDecoration ??
                BoxDecoration(
                  color: theme.colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(16),
                ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onAnalisiAiTap,
                borderRadius: BorderRadius.circular(16),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      Icon(
                        Icons.auto_awesome,
                        color: theme
                            .extension<AppCardTheme>()
                            ?.contentColor,
                        size: 28,
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Piano con Analisi AI',
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: theme
                                    .extension<AppCardTheme>()
                                    ?.contentColor,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Commento personalizzato su carico, recupero e obiettivi (Gemini)',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme
                                    .extension<AppCardTheme>()
                                    ?.contentColorMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        Icons.arrow_forward_ios,
                        size: 16,
                        color: theme
                            .extension<AppCardTheme>()
                            ?.contentColorMuted,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TodayActivityRow extends StatelessWidget {
  const _TodayActivityRow({required this.data});

  final FitnessData data;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final name = data.stravaActivityName ?? data.stravaActivityType;
    final dur = data.stravaElapsedMinutes;
    final durStr =
        dur >= 60 ? '${(dur / 60).floor()}h ${(dur % 60).round()}m' : '${dur.round()} min';

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(
            Icons.directions_run,
            size: 18,
            color: theme.colorScheme.outline,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall,
            ),
          ),
          Text(
            durStr,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _SuggestionTile extends StatelessWidget {
  const _SuggestionTile({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: theme.colorScheme.outline.withValues(alpha: 0.15),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: theme.colorScheme.primary, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    body,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
