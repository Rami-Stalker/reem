import 'package:equatable/equatable.dart';

class ChatAttachmentEntity extends Equatable {
  const ChatAttachmentEntity({
    required this.id,
    required this.kind,
    required this.url,
    this.mimeType,
    this.fileName,
    this.sizeBytes,
    this.width,
    this.height,
    this.durationMs,
  });

  final String id;
  final String kind;
  final String url;
  final String? mimeType;
  final String? fileName;
  final int? sizeBytes;
  final int? width;
  final int? height;
  final int? durationMs;

  @override
  List<Object?> get props => [
        id,
        kind,
        url,
        mimeType,
        fileName,
        sizeBytes,
        width,
        height,
        durationMs,
      ];
}

class ChatMessageEntity extends Equatable {
  const ChatMessageEntity({
    required this.id,
    required this.chatId,
    required this.senderId,
    required this.content,
    required this.sentAt,
    required this.isMine,
    this.kind = 'text',
    this.status = 'sent',
    this.attachments = const [],
    this.deliveredAt,
    this.readAt,
  });

  final String id;
  final String chatId;
  final String senderId;
  final String content;
  final DateTime sentAt;
  final bool isMine;
  final String kind;
  final String status;
  final List<ChatAttachmentEntity> attachments;
  final DateTime? deliveredAt;
  final DateTime? readAt;

  bool get isImage => kind == 'image' || attachments.any((a) => a.kind == 'image');
  bool get isVoice => kind == 'voice' || attachments.any((a) => a.kind == 'voice');
  bool get isRead => status == 'read' || readAt != null;
  bool get isDelivered => status == 'delivered' || isRead || deliveredAt != null;

  @override
  List<Object?> get props => [
        id,
        chatId,
        senderId,
        content,
        sentAt,
        isMine,
        kind,
        status,
        attachments,
        deliveredAt,
        readAt,
      ];
}
