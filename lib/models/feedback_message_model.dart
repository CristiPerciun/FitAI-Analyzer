import 'package:cloud_firestore/cloud_firestore.dart';

/// Messaggio feedback utente ↔ admin in `users/{uid}/feedback/{id}`.
class FeedbackMessage {
  static const String senderUser = 'user';
  static const String senderAdmin = 'admin';
  static const int maxTextLength = 2000;

  final String? id;
  final String text;
  final DateTime? createdAt;
  final String sender;

  const FeedbackMessage({
    this.id,
    required this.text,
    this.createdAt,
    required this.sender,
  });

  bool get isFromUser => sender == senderUser;
  bool get isFromAdmin => sender == senderAdmin;

  Map<String, dynamic> toFirestore() => {
        'text': text,
        'sender': sender,
        'created_at': FieldValue.serverTimestamp(),
      };

  factory FeedbackMessage.fromFirestore(
    Map<String, dynamic> data, {
    String? documentId,
  }) {
    final ts = data['created_at'];
    DateTime? createdAt;
    if (ts is Timestamp) {
      createdAt = ts.toDate();
    }

    return FeedbackMessage(
      id: documentId,
      text: data['text']?.toString() ?? '',
      createdAt: createdAt,
      sender: data['sender']?.toString() ?? senderUser,
    );
  }
}
