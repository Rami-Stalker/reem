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

/// A message's own local status, above and beyond what the server reports.
///
/// [pending] and [failed] only ever describe her own outgoing message, and
/// only between the tap and the reply. They exist because a conversation that
/// shows nothing at all until the round trip finishes reads as a broken
/// conversation on a Syrian mobile connection — which is the whole of the
/// «التأخر في وصول الرسائل» complaint on the sending side.
enum ChatMessageDelivery { pending, sent, failed }

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
    this.clientId,
    this.delivery = ChatMessageDelivery.sent,
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

  /// The id this handset gave the message before the server had one.
  ///
  /// It travels with the send and comes back on the stored row, which is what
  /// lets the optimistic bubble be *replaced* rather than joined by a second
  /// copy of itself — including when the socket's echo arrives before the
  /// reply to the POST does.
  final String? clientId;

  final ChatMessageDelivery delivery;

  bool get isPending => delivery == ChatMessageDelivery.pending;
  bool get isFailed => delivery == ChatMessageDelivery.failed;

  bool get isImage => kind == 'image' || attachments.any((a) => a.kind == 'image');
  bool get isVoice => kind == 'voice' || attachments.any((a) => a.kind == 'voice');
  bool get isRead => status == 'read' || readAt != null;
  bool get isDelivered =>
      !isPending &&
      !isFailed &&
      (status == 'delivered' || isRead || deliveredAt != null);

  ChatMessageEntity copyWith({
    String? status,
    DateTime? deliveredAt,
    DateTime? readAt,
    ChatMessageDelivery? delivery,
  }) => ChatMessageEntity(
    id: id,
    chatId: chatId,
    senderId: senderId,
    content: content,
    sentAt: sentAt,
    isMine: isMine,
    kind: kind,
    status: status ?? this.status,
    attachments: attachments,
    deliveredAt: deliveredAt ?? this.deliveredAt,
    readAt: readAt ?? this.readAt,
    clientId: clientId,
    delivery: delivery ?? this.delivery,
  );

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
        clientId,
        delivery,
      ];
}
