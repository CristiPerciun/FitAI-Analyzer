import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fitai_analyzer/models/feedback_message_model.dart';
import 'package:fitai_analyzer/utils/platform_firestore_fix.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final feedbackServiceProvider = Provider<FeedbackService>((ref) {
  return FeedbackService();
});

class FeedbackService {
  Stream<List<FeedbackMessage>> messagesStream(String uid) {
    final query = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('feedback')
        .orderBy('created_at');
    return querySnapshotStream(query).map(
      (snapshot) => snapshot.docs
          .map(
            (d) => FeedbackMessage.fromFirestore(
              d.data(),
              documentId: d.id,
            ),
          )
          .toList(),
    );
  }

  Future<void> sendUserMessage(String uid, String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError('Il messaggio non può essere vuoto.');
    }
    if (trimmed.length > FeedbackMessage.maxTextLength) {
      throw ArgumentError(
        'Il messaggio supera ${FeedbackMessage.maxTextLength} caratteri.',
      );
    }

    await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('feedback')
        .add(
          FeedbackMessage(
            text: trimmed,
            sender: FeedbackMessage.senderUser,
          ).toFirestore(),
        );
  }
}
