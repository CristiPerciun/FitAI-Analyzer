import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fitai_analyzer/models/fitness_data.dart';
import 'package:fitai_analyzer/providers/auth_notifier.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Stream provider per listen real-time ai dati Strava da Firestore.
final healthDataStreamProvider = StreamProvider.autoDispose<List<FitnessData>>(
  (ref) {
    final uid = ref.watch(authNotifierProvider).user?.uid;
    if (uid == null) return Stream.value([]);
    return FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('health_data')
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => FitnessData.fromJson({...d.data(), 'id': d.id}))
            .toList());
  },
);
