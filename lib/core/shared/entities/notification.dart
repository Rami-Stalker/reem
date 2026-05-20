import 'package:equatable/equatable.dart';

enum NotificationType {
  like,
  comment,
  follow,
  message,
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
    required this.isRead,
    required this.createdAt,
  });

  @override
  List<Object?> get props => [
        id,
        title,
        body,
        type,
        isRead,
        createdAt,
      ];
}