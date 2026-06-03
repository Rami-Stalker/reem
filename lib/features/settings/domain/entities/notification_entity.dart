import 'package:equatable/equatable.dart';

enum NotificationEntityType {
  like,
  comment,
  follow,
  message,
  order,
  promo,
}

class NotificationEntity extends Equatable {
  const NotificationEntity({
    required this.id,
    required this.title,
    required this.body,
    required this.type,
    required this.isRead,
    required this.createdAt,
  });

  final String id;
  final String title;
  final String body;
  final NotificationEntityType type;
  final bool isRead;
  final DateTime createdAt;

  @override
  List<Object?> get props => [id, title, body, type, isRead, createdAt];
}
