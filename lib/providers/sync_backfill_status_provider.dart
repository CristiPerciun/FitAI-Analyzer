import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fitai_analyzer/providers/auth_notifier.dart';
import 'package:fitai_analyzer/utils/platform_firestore_fix.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Stato backfill lato server (`users/{uid}/sync_status/backfill`).
class SyncBackfillStatus {
  final String? status;
  final double? progress;
  final String? message;
  final String? source;

  const SyncBackfillStatus({
    this.status,
    this.progress,
    this.message,
    this.source,
  });

  bool get isActive {
    final s = status ?? '';
    return s == 'pending' || s == 'processing';
  }

  factory SyncBackfillStatus.fromMap(Map<String, dynamic>? m) {
    if (m == null) return const SyncBackfillStatus();
    final p = m['progress'];
    return SyncBackfillStatus(
      status: m['status']?.toString(),
      progress: p is num ? p.toDouble() : null,
      message: m['message']?.toString(),
      source: m['source']?.toString(),
    );
  }
}

final syncBackfillStatusStreamProvider =
    StreamProvider.autoDispose<SyncBackfillStatus?>((ref) async* {
  final uid = ref.watch(authNotifierProvider.select((s) => s.user?.uid));
  if (uid == null) {
    yield null;
    return;
  }
  final docRef = FirebaseFirestore.instance
      .collection('users')
      .doc(uid)
      .collection('sync_status')
      .doc('backfill');
  await for (final snap in documentSnapshotStream(docRef)) {
    if (!snap.exists) {
      yield const SyncBackfillStatus();
      continue;
    }
    yield SyncBackfillStatus.fromMap(snap.data());
  }
});
