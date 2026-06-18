// shared/entities/notification.dart

import 'package:equatable/equatable.dart';

enum NotificationType { like, comment, follow, message, order, promo }

extension NotificationTypeX on NotificationType {
  String get wire => name;

  static NotificationType fromWire(String? value) =>
      switch ((value ?? '').toLowerCase()) {
        'comment' => NotificationType.comment,
        'follow' => NotificationType.follow,
        'message' => NotificationType.message,
        'order' => NotificationType.order,
        'promo' => NotificationType.promo,
        _ => NotificationType.like,
      };
}

class AppNotification extends Equatable {
  final String id;
  final String title;
  final String body;
  final NotificationType type;
  final bool isRead;
  final DateTime createdAt;

  const AppNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.type,
    this.isRead = false,
    required this.createdAt,
  });

  @override
  List<Object?> get props => [id, title, body, type, isRead, createdAt];
}
