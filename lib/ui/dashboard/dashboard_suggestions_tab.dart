import 'package:fitai_analyzer/models/ai_current_allenamenti_model.dart';
import 'package:fitai_analyzer/models/fitness_data.dart';
import 'package:fitai_analyzer/providers/dashboard_activity_providers.dart';
import 'package:fitai_analyzer/providers/data_sync_notifier.dart';
import 'package:fitai_analyzer/providers/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Secondo tab Allenamenti: riepilogo giornata e spazio per suggerimenti pratici.
class DashboardSuggestionsTab extends ConsumerWidget {
  const DashboardSuggestionsTab({super.key});

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
    final allenamentiAsync = ref.watch(aiCurrentAllenamentiStreamProvider);
    final allenamentiObiettivo = allenamentiAsync.valueOrNull;

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
          _WorkoutObjectiveCard(obiettivo: allenamentiObiettivo),
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
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.info_outline,
                size: 14,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 6),
              Text(
                'Obiettivi generati tramite Analisi nella Home',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
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

/// Card che mostra l'obiettivo di allenamento giornaliero generato dal prompt AI unificato.
/// I dati arrivano da `ai_current/allenamenti` via [aiCurrentAllenamentiStreamProvider].
class _WorkoutObjectiveCard extends StatelessWidget {
  const _WorkoutObjectiveCard({this.obiettivo});

  final AiCurrentAllenamentiModel? obiettivo;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasData = obiettivo != null && obiettivo!.hasContent;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: theme.colorScheme.primary.withValues(alpha: 0.3),
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
                  Icons.fitness_center_outlined,
                  color: theme.colorScheme.primary,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'Obiettivo allenamento di oggi',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (!hasData)
              Text(
                'Nessun obiettivo AI per oggi. Premi "Analisi" in Home per generarlo.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              )
            else ...[
              if (obiettivo!.tipo.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    obiettivo!.tipo,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: theme.colorScheme.onPrimaryContainer,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              if (obiettivo!.tipo.isNotEmpty) const SizedBox(height: 8),
              Text(
                obiettivo!.descrizione,
                style: theme.textTheme.bodyMedium?.copyWith(height: 1.4),
              ),
              if (obiettivo!.durataMins > 0 || obiettivo!.intensita.isNotEmpty) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    if (obiettivo!.durataMins > 0) ...[
                      Icon(
                        Icons.timer_outlined,
                        size: 14,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${obiettivo!.durataMins} min',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(width: 12),
                    ],
                    if (obiettivo!.intensita.isNotEmpty) ...[
                      Icon(
                        Icons.speed_outlined,
                        size: 14,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        obiettivo!.intensita,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ],
          ],
        ),
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
