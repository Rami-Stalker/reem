import 'package:equatable/equatable.dart';

class ChatThreadEntity extends Equatable {
  const ChatThreadEntity({
    required this.id,
    required this.title,
    required this.avatarUrl,
    required this.lastMessage,
    required this.unreadCount,
    required this.updatedAt,
    this.isOnline = false,
  });

  final String id;
  final String title;
  final String avatarUrl;
  final String lastMessage;
  final int unreadCount;
  final DateTime updatedAt;
  final bool isOnline;

  @override
  List<Object?> get props =>
      [id, title, avatarUrl, lastMessage, unreadCount, updatedAt, isOnline];
}
