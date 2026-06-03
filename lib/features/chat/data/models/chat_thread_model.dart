import '../../domain/entities/chat_thread_entity.dart';

class ChatThreadModel extends ChatThreadEntity {
  const ChatThreadModel({
    required super.id,
    required super.title,
    required super.avatarUrl,
    required super.lastMessage,
    required super.unreadCount,
    required super.updatedAt,
    super.isOnline,
  });

  factory ChatThreadModel.fromJson(Map<String, dynamic> json) {
    return ChatThreadModel(
      id: json['id'] as String,
      title: json['title'] as String? ??
          json['name'] as String? ??
          'Chat',
      avatarUrl: json['avatar_url'] as String? ??
          json['image'] as String? ??
          '',
      lastMessage: json['last_message'] as String? ?? '',
      unreadCount: json['unread_count'] as int? ?? 0,
      updatedAt: DateTime.parse(
        json['updated_at'] as String? ??
            json['last_seen'] as String? ??
            DateTime.now().toIso8601String(),
      ),
      isOnline: json['online'] as bool? ?? json['is_online'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'avatar_url': avatarUrl,
      'last_message': lastMessage,
      'unread_count': unreadCount,
      'updated_at': updatedAt.toIso8601String(),
      'online': isOnline,
    };
  }
}
