import '../../domain/entities/chat_message_entity.dart';

class ChatMessageModel extends ChatMessageEntity {
  const ChatMessageModel({
    required super.id,
    required super.chatId,
    required super.senderId,
    required super.content,
    required super.sentAt,
    required super.isMine,
  });

  factory ChatMessageModel.fromJson(
    Map<String, dynamic> json, {
    String? chatId,
    String? currentUserId,
  }) {
    final senderId = json['sender_id'] as String? ?? '';
    return ChatMessageModel(
      id: json['id'] as String,
      chatId: chatId ?? json['chat_id'] as String? ?? '',
      senderId: senderId,
      content: json['content'] as String? ?? json['message'] as String? ?? '',
      sentAt: DateTime.parse(
        json['sent_at'] as String? ??
            json['created_at'] as String? ??
            DateTime.now().toIso8601String(),
      ),
      isMine: json['is_mine'] as bool? ??
          (currentUserId != null && senderId == currentUserId),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'chat_id': chatId,
      'sender_id': senderId,
      'content': content,
      'sent_at': sentAt.toIso8601String(),
      'is_mine': isMine,
    };
  }
}
