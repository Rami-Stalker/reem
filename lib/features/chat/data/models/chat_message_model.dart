import 'package:ohara/core/shared/value_objects/money.dart';
import 'package:ohara/features/chat/domain/entities/chat_message_entity.dart';

class ChatAttachmentModel extends ChatAttachmentEntity {
  const ChatAttachmentModel({
    required super.id,
    required super.kind,
    required super.url,
    super.mimeType,
    super.fileName,
    super.sizeBytes,
    super.width,
    super.height,
    super.durationMs,
  });

  factory ChatAttachmentModel.fromJson(Map<String, dynamic> json) {
    return ChatAttachmentModel(
      id: json['id'] as String? ?? '',
      kind: json['kind'] as String? ?? 'image',
      url: json['url'] as String? ?? '',
      mimeType: json['mime_type'] as String?,
      fileName: json['file_name'] as String?,
      sizeBytes: json['size_bytes'] as int?,
      width: json['width'] as int?,
      height: json['height'] as int?,
      durationMs: json['duration_ms'] as int?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'kind': kind.toUpperCase(),
      'url': url,
      if (mimeType != null) 'mime_type': mimeType,
      if (fileName != null) 'file_name': fileName,
      if (sizeBytes != null) 'size_bytes': sizeBytes,
      if (width != null) 'width': width,
      if (height != null) 'height': height,
      if (durationMs != null) 'duration_ms': durationMs,
    };
  }
}

class ChatMessageModel extends ChatMessageEntity {
  const ChatMessageModel({
    required super.id,
    required super.chatId,
    required super.senderId,
    required super.content,
    required super.sentAt,
    required super.isMine,
    super.kind,
    super.status,
    super.attachments,
    super.deliveredAt,
    super.readAt,
    super.clientId,
    super.product,
  });

  /// [currentUserId], when known, decides [isMine] by comparing it with the
  /// sender — the one answer that cannot be wrong. The payload's `is_mine` is
  /// only the fallback: a message relayed over the socket carried the
  /// *sender's* `is_mine` to everyone, and the recipient drew it as her own.
  factory ChatMessageModel.fromJson(
    Map<String, dynamic> json, {
    String? chatId,
    String? currentUserId,
  }) {
    final senderId = json['sender_id'] as String? ?? '';
    final attachments = (json['attachments'] as List? ?? const [])
        .whereType<Map>()
        .map((e) => ChatAttachmentModel.fromJson(Map<String, dynamic>.from(e)))
        .toList();
    return ChatMessageModel(
      id: json['id'] as String,
      chatId: chatId ?? json['chat_id'] as String? ?? '',
      senderId: senderId,
      content: json['content'] as String? ?? json['message'] as String? ?? '',
      kind: (json['kind'] as String? ?? json['type'] as String? ?? 'text')
          .toLowerCase(),
      status: (json['status'] as String? ?? 'sent').toLowerCase(),
      attachments: attachments,
      deliveredAt: _date(json['delivered_at']),
      readAt: _date(json['read_at']),
      // The server speaks UTC. Parsed as-is, every clock time and every "today"
      // divider was drawn in UTC — three hours off in Damascus.
      sentAt: _date(json['sent_at']) ??
          _date(json['created_at']) ??
          DateTime.now(),
      isMine: currentUserId != null && currentUserId.isNotEmpty
          ? senderId == currentUserId
          : json['is_mine'] as bool? ?? false,
      clientId: json['client_id'] as String?,
      product: _productRef(json['metadata']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'chat_id': chatId,
      'sender_id': senderId,
      'content': content,
      'kind': kind,
      'status': status,
      'attachments': attachments
          .whereType<ChatAttachmentModel>()
          .map((attachment) => attachment.toJson())
          .toList(),
      'sent_at': sentAt.toIso8601String(),
      'delivered_at': deliveredAt?.toIso8601String(),
      'read_at': readAt?.toIso8601String(),
      'is_mine': isMine,
      'client_id': ?clientId,
      if (product case final product?)
        'metadata': {
          'product': {
            'id': product.id,
            'title': product.title,
            'image_url': product.imageUrl,
            'price': product.price?.toJson(),
          },
        },
    };
  }
}

/// `metadata.product`, when the message was sent about a piece.
ChatProductRef? _productRef(dynamic metadata) {
  if (metadata is! Map) return null;
  final product = metadata['product'];
  if (product is! Map) return null;
  final id = product['id'];
  if (id is! String || id.isEmpty) return null;
  return ChatProductRef(
    id: id,
    title: product['title'] as String? ?? '',
    imageUrl: product['image_url'] as String?,
    price: Money.tryFromJson(product['price']),
  );
}

DateTime? _date(dynamic value) {
  if (value is! String || value.isEmpty) return null;
  return DateTime.tryParse(value)?.toLocal();
}
