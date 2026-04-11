import 'package:fitai_analyzer/models/fitness_data.dart';
import 'package:fitai_analyzer/services/strava_service.dart';
import 'package:fitai_analyzer/ui/widgets/activity_heart_rate_chart_card.dart';
import 'package:fitai_analyzer/ui/widgets/garmin_activity_detail_card.dart';
import 'package:fitai_analyzer/ui/widgets/strava_activity_card.dart';
import 'package:fitai_analyzer/utils/activity_hr_series.dart';
import 'package:fitai_analyzer/utils/garmin_activity_chart_parsers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ActivityDetailScreen extends ConsumerStatefulWidget {
  const ActivityDetailScreen({
    super.key,
    required this.activity,
  });

  final FitnessData activity;

  @override
  ConsumerState<ActivityDetailScreen> createState() => _ActivityDetailScreenState();
}

class _ActivityDetailScreenState extends ConsumerState<ActivityDetailScreen> {
  StravaActivity? _stravaDetailed;
  String? _stravaError;
  bool _isLoadingStrava = false;

  List<ActivityHrPoint>? _hrPoints;
  String? _hrSourceLabel;
  bool _isLoadingHr = false;

  @override
  void initState() {
    super.initState();
    _loadStravaDetailIfNeeded();
    _loadHeartRateSeries();
  }

  Future<void> _loadStravaDetailIfNeeded() async {
    final base = StravaActivity.fromFitnessData(widget.activity);
    final detailId = widget.activity.detailActivityId;
    final hasStravaDetail = widget.activity.containsStravaData &&
        detailId != null &&
        base.id > 0;
    if (!hasStravaDetail) return;

    setState(() => _isLoadingStrava = true);
    try {
      final detailed = await ref.read(stravaServiceProvider).getDetailedActivity(detailId);
      if (!mounted) return;
      setState(() => _stravaDetailed = detailed);
    } catch (e) {
      if (!mounted) return;
      setState(() => _stravaError = e.toString());
    } finally {
      if (mounted) {
        setState(() => _isLoadingStrava = false);
      }
    }
  }

  /// Strava Streams solo se in garmin_raw non c’è già una serie FC (evita doppio grafico: quella Garmin è in [GarminActivityChartsSection]).
  Future<void> _loadHeartRateSeries() async {
    if (extractGarminHeartRateSeries(widget.activity.garminRaw).length >= 2) {
      return;
    }
    final detailId = widget.activity.detailActivityId;
    final tryStrava = widget.activity.containsStravaData &&
        detailId != null &&
        detailId > 0;
    if (!tryStrava) return;

    if (mounted) setState(() => _isLoadingHr = true);
    try {
      final svc = ref.read(stravaServiceProvider);
      if (await svc.isConnected()) {
        final pts = await svc.fetchHeartRateSeries(detailId);
        if (!mounted) return;
        if (pts != null && pts.length >= 2) {
          setState(() {
            _hrPoints = pts;
            _hrSourceLabel = 'Serie da Strava (API Streams)';
            _isLoadingHr = false;
          });
          return;
        }
      }
    } catch (_) {}
    if (mounted) setState(() => _isLoadingHr = false);
  }

  @override
  Widget build(BuildContext context) {
    final activity = widget.activity;
    final title = activity.stravaActivityName?.trim().isNotEmpty == true
        ? activity.stravaActivityName!.trim()
        : 'Dettaglio attivita';
    final hasGarminData = activity.source == 'garmin' ||
        activity.source == 'dual' ||
        activity.hasGarmin ||
        activity.garminRaw != null;
    final fallbackStrava = StravaActivity.fromFitnessData(activity);
    final stravaCardData = _stravaDetailed ?? fallbackStrava;
    final hasStravaData = activity.containsStravaData || fallbackStrava.id > 0;
    final laps = _stravaDetailed?.laps ?? const [];

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          if (hasStravaData) ...[
            Text('Dettaglio Strava', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            StravaActivityCard(activity: stravaCardData),
            if (_isLoadingStrava)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: LinearProgressIndicator(minHeight: 2),
              ),
            if (_stravaError != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'Dettaglio completo Strava non disponibile: $_stravaError',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.error,
                      ),
                ),
              ),
          ],
          if (_isLoadingHr) ...[
            const SizedBox(height: 12),
            const LinearProgressIndicator(minHeight: 2),
          ],
          if (_hrPoints != null && _hrPoints!.length >= 2) ...[
            const SizedBox(height: 16),
            ActivityHeartRateChartCard(
              points: _hrPoints!,
              sourceLabel: _hrSourceLabel,
            ),
          ],
          if (hasGarminData) ...[
            const SizedBox(height: 16),
            Text('Dettaglio Garmin', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            GarminActivityDetailCard(activity: activity),
          ],
          if (laps.isNotEmpty) ...[
            const SizedBox(height: 16),
            _LapsChartCard(laps: laps),
          ],
        ],
      ),
    );
  }
}

class _LapsChartCard extends StatelessWidget {
  const _LapsChartCard({required this.laps});

  final List<dynamic> laps;

  @override
  Widget build(BuildContext context) {
    final lapRows = laps.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
    final values = lapRows.map((m) => ((m['average_speed'] as num?)?.toDouble() ?? 0)).toList();
    final maxSpeed = values.fold<double>(0, (p, e) => e > p ? e : p);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Grafico giri', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 10),
            for (final row in lapRows.take(10))
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _LapBarRow(
                  lapIndex: (row['lap_index'] as num?)?.toInt() ?? 0,
                  speedMs: (row['average_speed'] as num?)?.toDouble() ?? 0,
                  distanceM: (row['distance'] as num?)?.toDouble() ?? 0,
                  maxSpeedMs: maxSpeed <= 0 ? 1 : maxSpeed,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _LapBarRow extends StatelessWidget {
  const _LapBarRow({
    required this.lapIndex,
    required this.speedMs,
    required this.distanceM,
    required this.maxSpeedMs,
  });

  final int lapIndex;
  final double speedMs;
  final double distanceM;
  final double maxSpeedMs;

  @override
  Widget build(BuildContext context) {
    final speedKmh = speedMs * 3.6;
    final ratio = (speedMs / maxSpeedMs).clamp(0.0, 1.0);
    return Row(
      children: [
        SizedBox(
          width: 64,
          child: Text(
            'Lap $lapIndex',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: ratio,
              minHeight: 10,
            ),
          ),
        ),
        const SizedBox(width: 10),
        SizedBox(
          width: 120,
          child: Text(
            '${(distanceM / 1000).toStringAsFixed(2)} km • ${speedKmh.toStringAsFixed(1)} km/h',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
      ],
    );
  }
}
