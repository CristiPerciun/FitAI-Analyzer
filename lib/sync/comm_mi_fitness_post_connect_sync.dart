import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:fitai_analyzer/providers/data_sync_notifier.dart';
import 'package:fitai_analyzer/providers/providers.dart';
import 'package:fitai_analyzer/services/garmin_service.dart';

/// Primo `/sync/delta` solo Mi Fitness dopo collegamento.
/// Non passa da [GarminSyncNotifier]: Garmin e Mi Fitness restano percorsi distinti sul client.
Future<Map<String, dynamic>> commMiFitnessRunInitialDelta(
  WidgetRef ref,
  String uid,
) async {
  final service = ref.read(garminServiceProvider);
  final last = await service.getLastSuccessfulSync(uid);
  return service.deltaSync(
    uid: uid,
    lastSuccessfulSync: last,
    sources: const ['mi_fitness'],
  );
}

/// Cache UI dopo un delta Mi Fitness (senza invalidare stato Garmin legato alle altre sorgenti).
void commMiFitnessInvalidateActivityCaches(WidgetRef ref) {
  ref.invalidate(activitiesStreamProvider);
  ref.invalidate(activitiesByDateProvider);
  ref.invalidate(activityDatesProvider);
  ref.invalidate(longevityHomePackageProvider);
}
