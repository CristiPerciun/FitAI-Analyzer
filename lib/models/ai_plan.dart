import 'package:cloud_firestore/cloud_firestore.dart';

/// Modello per piano generato dall'AI.
class AiPlan {
  final String id;
  final String content;
  final DateTime createdAt;
  final String? userId;

  const AiPlan({
    required this.id,
    required this.content,
    required this.createdAt,
    this.userId,
  });

  factory AiPlan.fromJson(Map<String, dynamic> json) {
    return AiPlan(
      id: json['id'] as String? ?? '',
      content: json['content'] as String? ?? '',
      createdAt:
          (json['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      userId: json['userId'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'content': content,
      'createdAt': Timestamp.fromDate(createdAt),
      'userId': userId,
    };
  }
}
