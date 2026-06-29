import 'package:fitai_analyzer/services/strava_service.dart';
import 'package:fitai_analyzer/utils/activity_hr_series.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Dettaglio completo attività Strava (API), keyed per `detailActivityId`.
/// Errore → `AsyncError` (la UI mostra un messaggio non bloccante).
final stravaDetailedActivityProvider = FutureProvider.autoDispose
    .family<StravaActivity?, int>((ref, detailId) async {
      if (detailId <= 0) return null;
      return ref.read(stravaServiceProvider).getDetailedActivity(detailId);
    });

/// Serie FC da Strava Streams (null se Strava non connesso o serie < 2 punti).
final stravaHeartRateSeriesProvider = FutureProvider.autoDispose
    .family<List<ActivityHrPoint>?, int>((ref, detailId) async {
      if (detailId <= 0) return null;
      final svc = ref.read(stravaServiceProvider);
      if (!await svc.isConnected()) return null;
      final pts = await svc.fetchHeartRateSeries(detailId);
      if (pts != null && pts.length >= 2) return pts;
      return null;
    });
