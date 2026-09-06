import 'package:reem/features/chat/domain/entities/chat_thread_entity.dart';

class ChatThreadModel extends ChatThreadEntity {
  const ChatThreadModel({
    required super.id,
    required super.title,
    required super.avatarUrl,
    required super.lastMessage,
    required super.unreadCount,
    required super.updatedAt,
    super.context,
    super.peerId,
    super.peerName,
    super.productId,
    super.sellerOrderId,
    super.lastSeenAt,
    super.isOnline,
  });

  factory ChatThreadModel.fromJson(Map<String, dynamic> json) {
    return ChatThreadModel(
      id: json['id'] as String,
      title: json['title'] as String? ?? json['name'] as String? ?? '',
      avatarUrl: json['avatar_url'] as String? ?? json['image'] as String? ?? '',
      lastMessage: json['last_message'] as String? ?? '',
      unreadCount: (json['unread_count'] as num?)?.toInt() ?? 0,
      updatedAt: _date(json['updated_at']) ?? DateTime.now(),
      context: _context(json['type']),
      peerId: json['peer_id'] as String?,
      peerName: json['peer_name'] as String?,
      productId: json['product_id'] as String?,
      sellerOrderId: json['seller_order_id'] as String?,
      lastSeenAt: _date(json['last_seen_at']),
      isOnline: json['online'] as bool? ?? json['is_online'] as bool? ?? false,
    );
  }

  /// The server sends the enum lower-cased. An unknown value is treated as a
  /// plain conversation rather than throwing: a new context type on the server
  /// must not crash an older build of the app.
  static ChatContext _context(Object? raw) {
    return switch (raw) {
      'product' => ChatContext.product,
      'order' => ChatContext.order,
      'support' => ChatContext.support,
      _ => ChatContext.direct,
    };
  }

  static DateTime? _date(Object? raw) =>
      raw is String ? DateTime.tryParse(raw)?.toLocal() : null;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': context.name,
      'title': title,
      'avatar_url': avatarUrl,
      'peer_id': peerId,
      'peer_name': peerName,
      'product_id': productId,
      'seller_order_id': sellerOrderId,
      'last_message': lastMessage,
      'unread_count': unreadCount,
      'updated_at': updatedAt.toIso8601String(),
      'last_seen_at': lastSeenAt?.toIso8601String(),
      'online': isOnline,
    };
  }
}
