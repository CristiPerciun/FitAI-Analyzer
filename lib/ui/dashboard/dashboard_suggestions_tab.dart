import 'package:fitai_analyzer/models/ai_current_allenamenti_model.dart';
import 'package:fitai_analyzer/models/fitness_data.dart';
import 'package:fitai_analyzer/providers/auth_notifier.dart';
import 'package:fitai_analyzer/providers/dashboard_activity_providers.dart';
import 'package:fitai_analyzer/providers/data_sync_notifier.dart';
import 'package:fitai_analyzer/providers/providers.dart';
import 'package:fitai_analyzer/theme/app_theme.dart';
import 'package:fitai_analyzer/ui/widgets/anim_progress_ring.dart';
import 'package:fitai_analyzer/ui/widgets/design/design.dart';
import 'package:fitai_analyzer/ui/widgets/nature_icon.dart';
import 'package:fitai_analyzer/utils/workout_goal_progress.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Secondo tab Allenamenti: riepilogo giornata e suggerimenti pratici,
/// resi come card illustrate (stile hand-drawn UI).
class DashboardSuggestionsTab extends ConsumerWidget {
  const DashboardSuggestionsTab({super.key});

  // Accenti natura coerenti coi pilastri (longevità).
  static const Color _cIdratazione = Color(0xFF5FB6C9); // lagoon teal
  static const Color _cRecupero = Color(0xFF8E7CC9); // soft violet
  static const Color _cConsistenza = Color(0xFFC9A227); // amber-gold

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

    final uid = ref.watch(authNotifierProvider).user?.uid;

    return RefreshIndicator(
      onRefresh: () =>
          refreshGarminSync(ref, uid, trigger: 'allenamenti_pull_to_refresh'),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
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
          _WorkoutObjectiveCard(
            obiettivo: allenamentiObiettivo,
            todayActivities: todayActs,
          ),
          const SizedBox(height: 16),
          _TodayMovementCard(activities: todayActs, kcal: kcalToday),
          const SizedBox(height: 20),
          Text(
            'CONSIGLI DI OGGI',
            style: AppText.sectionTitle(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          _SuggestionCard(
            asset: NatureIcons.water,
            tint: _cIdratazione,
            title: 'Idratazione',
            body:
                'Dopo sessioni con sudorazione, recupera liquidi a piccoli sorsi nel corso della serata.',
          ),
          const SizedBox(height: 12),
          _SuggestionCard(
            asset: NatureIcons.recovery,
            tint: _cRecupero,
            title: 'Recupero',
            body:
                'Se oggi hai spinto forte, preferisci sonno regolare e una seduta leggera domani oppure riposo attivo (camminata).',
          ),
          const SizedBox(height: 12),
          _SuggestionCard(
            asset: NatureIcons.repeat,
            tint: _cConsistenza,
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

/// Card "Oggi in movimento": kcal bruciate + righe attività con icona-tipo.
class _TodayMovementCard extends StatelessWidget {
  const _TodayMovementCard({required this.activities, required this.kcal});

  final List<FitnessData> activities;
  final double kcal;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return FitSoftCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              NatureIcon(
                NatureIcons.intensity,
                color: theme.colorScheme.primary,
                size: 22,
                glow: true,
              ),
              const SizedBox(width: 8),
              Text(
                'Oggi in movimento',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            activities.isEmpty
                ? 'Nessuna attività registrata per oggi. Collega Strava o attendi la sync Garmin.'
                : '${activities.length} attività · ${kcal.toStringAsFixed(0)} kcal bruciate (stima da dispositivo / Strava)',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          if (activities.isNotEmpty) ...[
            const SizedBox(height: 12),
            ...activities.take(4).map((a) => _TodayActivityRow(data: a)),
            if (activities.length > 4)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  '+ altre ${activities.length - 4} nel tab Progressi',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.primary,
                  ),
                ),
              ),
          ],
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
    final asset = NatureIcons.forWorkoutType(
      '${data.stravaActivityType} ${data.stravaActivityName ?? ''}',
    );
    final dur = data.stravaElapsedMinutes;
    final durStr = dur >= 60
        ? '${(dur / 60).floor()}h ${(dur % 60).round()}m'
        : '${dur.round()} min';

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          NatureIcon(
            asset,
            size: 20,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 10),
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
  const _WorkoutObjectiveCard({this.obiettivo, required this.todayActivities});

  final AiCurrentAllenamentiModel? obiettivo;
  final List<FitnessData> todayActivities;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final hasData = obiettivo != null && obiettivo!.hasContent;
    final ringTrack = cs.onSurface.withValues(alpha: isDark ? 0.05 : 0.10);

    double? progressDisplay;
    if (hasData) {
      progressDisplay = workoutProgressForDisplay(
        goal: obiettivo,
        todayActivities: todayActivities,
      );
    }

    final ack = obiettivo?.doneTodaySummary.trim() ?? '';
    final asset = NatureIcons.forWorkoutType(obiettivo?.tipo ?? '');

    return FitHeroCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              NatureIconBadge(
                asset,
                tint: cs.primary,
                boxSize: 46,
                iconSize: 28,
                radius: 14,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'OBIETTIVO DI OGGI',
                      style: AppText.sectionTitle(
                        fontSize: 11,
                        color: cs.primary,
                      ),
                    ),
                    Text(
                      'Allenamento consigliato',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (!hasData)
            Text(
              'Nessun obiettivo AI per oggi. Premi "Analisi" in Home per generarlo.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: cs.onSurfaceVariant,
              ),
            )
          else ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Stack(
                  alignment: Alignment.center,
                  children: [
                    AnimProgressRing(
                      progress: progressDisplay ?? 0,
                      size: 100,
                      strokeWidth: 8,
                      accentColor: cs.primary,
                      trackColor: ringTrack,
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${((progressDisplay ?? 0) * 100).round()}',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '% obiettivo',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (obiettivo!.tipo.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: FitBadgePill(
                            label: obiettivo!.tipo,
                            variant: FitBadgeVariant.solid,
                          ),
                        ),
                      Text(
                        obiettivo!.descrizione,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          height: 1.4,
                        ),
                      ),
                      if (obiettivo!.durataMins > 0 ||
                          obiettivo!.intensita.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 14,
                          runSpacing: 6,
                          children: [
                            if (obiettivo!.durataMins > 0)
                              _MetaChip(
                                asset: NatureIcons.timer,
                                label: '${obiettivo!.durataMins} min',
                              ),
                            if (obiettivo!.intensita.isNotEmpty)
                              _MetaChip(
                                asset: NatureIcons.intensity,
                                label: obiettivo!.intensita,
                              ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            if (ack.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHighest.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.check_circle_outline,
                      size: 18,
                      color: cs.primary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        ack,
                        style: theme.textTheme.bodySmall?.copyWith(
                          height: 1.35,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

/// Chip "icona disegnata + valore" (durata, intensità) sotto l'obiettivo.
class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.asset, required this.label});

  final String asset;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        NatureIcon(asset, size: 16, color: theme.colorScheme.onSurfaceVariant),
        const SizedBox(width: 4),
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

/// Card consiglio con illustrazione hand-drawn e accento colore dedicato.
class _SuggestionCard extends StatelessWidget {
  const _SuggestionCard({
    required this.asset,
    required this.tint,
    required this.title,
    required this.body,
  });

  final String asset;
  final Color tint;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return FitSoftCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          NatureIconBadge(asset, tint: tint, boxSize: 52, iconSize: 30),
          const SizedBox(width: 14),
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
    );
  }
}
