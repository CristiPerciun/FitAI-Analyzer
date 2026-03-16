import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show defaultTargetPlatform, TargetPlatform;

/// Workaround per errori "non-platform thread" su Windows con Firebase.
/// Su Windows i plugin firebase_auth e cloud_firestore inviano messaggi da thread
/// non-platform; usare polling invece di snapshots() evita il problema.
/// Vedi: https://github.com/firebase/flutterfire/issues/11933

bool get isWindows => defaultTargetPlatform == TargetPlatform.windows;

/// Intervallo di polling su Windows (15 secondi) per evitare rebuild continui.
const Duration _pollInterval = Duration(seconds: 15);

/// Stream da Query: su Windows usa get() con polling, altrimenti snapshots().
Stream<QuerySnapshot<Map<String, dynamic>>> querySnapshotStream(
  Query<Map<String, dynamic>> query,
) {
  if (!isWindows) return query.snapshots();
  return _pollQuery(query);
}

Stream<QuerySnapshot<Map<String, dynamic>>> _pollQuery(
  Query<Map<String, dynamic>> query,
) async* {
  yield await query.get();
  await for (final _ in Stream.periodic(_pollInterval)) {
    yield await query.get();
  }
}

/// Stream da DocumentReference: su Windows usa get() con polling, altrimenti snapshots().
Stream<DocumentSnapshot<Map<String, dynamic>>> documentSnapshotStream(
  DocumentReference<Map<String, dynamic>> ref,
) {
  if (!isWindows) return ref.snapshots();
  return _pollDocument(ref);
}

Stream<DocumentSnapshot<Map<String, dynamic>>> _pollDocument(
  DocumentReference<Map<String, dynamic>> ref,
) async* {
  yield await ref.get();
  await for (final _ in Stream.periodic(_pollInterval)) {
    yield await ref.get();
  }
}
