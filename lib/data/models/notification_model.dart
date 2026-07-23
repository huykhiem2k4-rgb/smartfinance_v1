class NotificationModel {
  final String notificationId;
  final String userId;
  final String title;
  final String message;
  final String type; // TRANSACTION | INVOICE | SYSTEM
  final String? referenceId;
  final bool isRead;
  final DateTime createdAt;

  NotificationModel({
    required this.notificationId,
    required this.userId,
    required this.title,
    required this.message,
    required this.type,
    this.referenceId,
    this.isRead = false,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() => {
    'notification_id': notificationId,
    'user_id': userId,
    'title': title,
    'message': message,
    'type': type,
    'reference_id': referenceId,
    'is_read': isRead ? 1 : 0,
    'created_at': createdAt.toIso8601String(),
  };

  factory NotificationModel.fromMap(Map<String, dynamic> m) => NotificationModel(
    notificationId: m['notification_id'] as String,
    userId: m['user_id'] as String,
    title: m['title'] as String,
    message: m['message'] as String,
    type: m['type'] as String,
    referenceId: m['reference_id'] as String?,
    isRead: (m['is_read'] as int?) == 1,
    createdAt: DateTime.tryParse(m['created_at'] as String? ?? '') ?? DateTime.now(),
  );

  NotificationModel copyWith({bool? isRead}) => NotificationModel(
    notificationId: notificationId,
    userId: userId,
    title: title,
    message: message,
    type: type,
    referenceId: referenceId,
    isRead: isRead ?? this.isRead,
    createdAt: createdAt,
  );
}
