import 'package:fitai_analyzer/models/fitness_data.dart';
import 'package:fitai_analyzer/providers/auth_notifier.dart';
import 'package:fitai_analyzer/providers/dashboard_activity_providers.dart';
import 'package:fitai_analyzer/providers/data_sync_notifier.dart';
import 'package:fitai_analyzer/providers/garmin_sync_notifier.dart';
import 'package:fitai_analyzer/providers/providers.dart';
import 'package:fitai_analyzer/services/strava_service.dart';
import 'package:fitai_analyzer/ui/widgets/compact_activity_card.dart';
import 'package:fitai_analyzer/ui/widgets/date_filter_chips.dart';
import 'package:fitai_analyzer/utils/date_utils.dart' show dateFilterAll;
import 'package:fitai_analyzer/ui/widgets/error_dialog.dart';
import 'package:fitai_analyzer/ui/widgets/garmin_activity_detail_card.dart';
import 'package:fitai_analyzer/ui/widgets/strava_activity_card.dart';
import 'package:fitai_analyzer/ui/dashboard/dashboard_suggestions_tab.dart';
import 'package:fitai_analyzer/ui/dashboard/widgets/activity_burn_bar_chart_card.dart';
import 'package:fitai_analyzer/ui/dashboard/widgets/activity_calendar_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _onSyncStrava(BuildContext context) async {
    await ref
        .read(authNotifierProvider.notifier)
        .startOAuth(
          'strava',
          onSuccess: () {
            ref.invalidate(activitiesStreamProvider);
            ref.read(selectedTabIndexProvider.notifier).state = 1;
          },
        );
  }

  @override
  Widget build(BuildContext context) {
    final uid = ref.watch(authNotifierProvider).user?.uid;
    final stravaConnected =
        ref.watch(stravaConnectedProvider).valueOrNull ?? false;
    final isGarminSyncing = ref.watch(
      garminSyncNotifierProvider.select((s) => s.isSyncing),
    );

    ref.listen(activitiesStreamProvider, (prev, next) {
      next.whenOrNull(
        error: (e, _) {
          if (context.mounted) showErrorDialog(context, e.toString());
        },
      );
    });

    return Scaffold(
          appBar: AppBar(
        title: const Text('Allenamenti'),
        bottom: TabBar(
          controller: _tabController,
          // 1. Disabilita lo scroll (questo permette ai tab di espandersi)
          isScrollable: false, 
          
          // 2. Rimuovi o imposta TabAlignment.fill (default se isScrollable è false)
          tabAlignment: TabAlignment.fill, 
          
          tabs: const [
            Tab(text: 'Suggerimenti e oggi'),
            Tab(text: 'Attività e progressi'),
          ],
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            if (isGarminSyncing) const LinearProgressIndicator(minHeight: 2),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  // 1. PRIMO TAB: Corrisponde a 'Suggerimenti e oggi'
                  const DashboardSuggestionsTab(),

                  // 2. SECONDO TAB: Corrisponde a 'Attività e progressi'
                  _buildProgressiTab(context, stravaConnected, uid),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressiTab(
    BuildContext context,
    bool stravaConnected,
    String? uid,
  ) {
    return RefreshIndicator(
      onRefresh: () => _onRefreshGarmin(uid),
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const ActivityCalendarCard(),
                  const SizedBox(height: 12),
                  const ActivityBurnBarChartCard(),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: _ActivitiesSection(
              stravaConnected: stravaConnected,
              onSyncTap: () => _onSyncStrava(context),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _onRefreshGarmin(String? uid) async {
    await refreshGarminSync(ref, uid, trigger: 'dashboard_pull_to_refresh');
  }
}

class _ActivitiesSection extends ConsumerWidget {
  const _ActivitiesSection({
    required this.stravaConnected,
    required this.onSyncTap,
  });

  final bool stravaConnected;
  final VoidCallback onSyncTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final byDate = ref.watch(activitiesByDateProvider);
    final dates = ref.watch(activityDatesProvider);
    final selectedDate = ref.watch(selectedDateFilterProvider);

    if (byDate.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: _EmptyActivitiesCard(
          isStravaConnected: stravaConnected,
          onSyncTap: onSyncTap,
        ),
      );
    }

    final todayStr = DateTime.now().toIso8601String().split('T')[0];
    final displayDates = selectedDate == null
        ? [todayStr]
        : selectedDate == dateFilterAll
        ? dates
        : [selectedDate];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'Date',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(height: 8),
        DateFilterChips(
          selectedDate: selectedDate,
          onDateSelected: (d) =>
              ref.read(selectedDateFilterProvider.notifier).state = d,
        ),
        const SizedBox(height: 20),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'Allenamenti',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
        ),
        const SizedBox(height: 12),
        ...displayDates.map((dateKey) {
          final activities = byDate[dateKey] ?? [];
          if (activities.isEmpty) return const SizedBox.shrink();
          final label = formatDateForDisplay(dateKey);
          return Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    label,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                ...activities.map((a) {
                  final activity = StravaActivity.fromFitnessData(a);
                  final detailId = a.detailActivityId;
                  final hasStravaDetail = a.containsStravaData &&
                      detailId != null &&
                      activity.id > 0;
                  final hasGarminData = a.source == 'garmin' ||
                      a.source == 'dual' ||
                      a.hasGarmin ||
                      a.garminRaw != null;
                  VoidCallback? onTap;
                  if (hasStravaDetail) {
                    onTap = () => _showStravaDetailDialog(context, detailId);
                  } else if (hasGarminData) {
                    onTap = () => _showGarminDetailDialog(context, a);
                  }
                  return CompactActivityCard(
                    activity: a,
                    onTap: onTap,
                  );
                }),
              ],
            ),
          );
        }),
      ],
    );
  }

  void _showStravaDetailDialog(BuildContext context, int activityId) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => _StravaDetailLoadingDialog(activityId: activityId),
    );
  }

  void _showGarminDetailDialog(BuildContext context, FitnessData activity) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => AlertDialog(
        title: Text(
          activity.stravaActivityName ??
              (activity.stravaActivityType.isNotEmpty
                  ? activity.stravaActivityType
                  : 'Attività Garmin'),
        ),
        content: SingleChildScrollView(
          child: GarminActivityDetailCard(activity: activity),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Chiudi'),
          ),
        ],
      ),
    );
  }
}

class _EmptyActivitiesCard extends StatelessWidget {
  const _EmptyActivitiesCard({
    required this.isStravaConnected,
    required this.onSyncTap,
  });

  final bool isStravaConnected;
  final VoidCallback onSyncTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: theme.colorScheme.outline.withValues(alpha: 0.2),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Icon(
              Icons.directions_bike_outlined,
              size: 48,
              color: theme.colorScheme.outline,
            ),
            const SizedBox(height: 16),
            Text(
              isStravaConnected
                  ? 'Nessuna attività. Sincronizza Strava o attendi la sync Garmin dal server.'
                  : 'Connetti Strava o attendi la sync Garmin dal server.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            if (isStravaConnected) ...[
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: onSyncTap,
                icon: const Icon(Icons.sync, size: 18),
                label: const Text('Sincronizza'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _StravaDetailLoadingDialog extends ConsumerStatefulWidget {
  const _StravaDetailLoadingDialog({required this.activityId});

  final int activityId;

  @override
  ConsumerState<_StravaDetailLoadingDialog> createState() =>
      _StravaDetailLoadingDialogState();
}

class _StravaDetailLoadingDialogState
    extends ConsumerState<_StravaDetailLoadingDialog> {
  StravaActivity? _detailed;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final act = await ref
          .read(stravaServiceProvider)
          .getDetailedActivity(widget.activityId);
      if (mounted) setState(() => _detailed = act);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return AlertDialog(
        title: const Text('Errore'),
        content: Text(_error!),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Chiudi'),
          ),
        ],
      );
    }
    if (_detailed != null) {
      return AlertDialog(
        title: Text(_detailed!.name),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              StravaActivityCard(activity: _detailed!),
              if (_detailed!.laps != null && _detailed!.laps!.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(
                  'Giri (${_detailed!.laps!.length})',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 8),
                ..._detailed!.laps!.take(5).map((lap) {
                  final m = lap is Map
                      ? lap as Map<String, dynamic>
                      : <String, dynamic>{};
                  final distM = (m['distance'] as num?)?.toDouble() ?? 0;
                  final speed = (m['average_speed'] as num?)?.toDouble();
                  final pace = speed != null && speed > 0
                      ? (1000 / 60 / speed).toStringAsFixed(1)
                      : '—';
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      'Lap ${m['lap_index'] ?? ''}: ${(distM / 1000).toStringAsFixed(2)} km • Pace $pace min/km',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  );
                }),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Chiudi'),
          ),
        ],
      );
    }
    return const AlertDialog(
      content: SizedBox(
        width: 80,
        height: 80,
        child: Center(child: CircularProgressIndicator()),
      ),
    );
  }
}
