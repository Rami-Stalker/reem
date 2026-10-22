import 'package:equatable/equatable.dart';

/// How a conversation came to exist. The server decides this — a chat opened
/// from a product is a `product` chat forever, even once the talk moves on —
/// and the list uses it to caption the row.
enum ChatContext { direct, product, order, support }

class ChatThreadEntity extends Equatable {
  const ChatThreadEntity({
    required this.id,
    required this.title,
    required this.avatarUrl,
    required this.lastMessage,
    required this.unreadCount,
    required this.updatedAt,
    this.context = ChatContext.direct,
    this.peerId,
    this.peerName,
    this.productId,
    this.sellerOrderId,
    this.lastSeenAt,
    this.isOnline = false,
  });

  final String id;
  final String title;
  final String avatarUrl;
  final String lastMessage;
  final int unreadCount;
  final DateTime updatedAt;
  final ChatContext context;

  /// The other side of the conversation. Null only for a malformed thread with
  /// no second participant; blocking and reporting are hidden when it is.
  final String? peerId;
  final String? peerName;

  /// What the conversation is about, when it is about something. A product
  /// chat carries the product; an order chat carries the seller's parcel.
  final String? productId;
  final String? sellerOrderId;

  /// When the peer was last online. Only meaningful while [isOnline] is false.
  final DateTime? lastSeenAt;
  final bool isOnline;

  bool get hasUnread => unreadCount > 0;

  ChatThreadEntity copyWith({
    String? lastMessage,
    int? unreadCount,
    DateTime? updatedAt,
    DateTime? lastSeenAt,
    bool? isOnline,
  }) {
    return ChatThreadEntity(
      id: id,
      title: title,
      avatarUrl: avatarUrl,
      lastMessage: lastMessage ?? this.lastMessage,
      unreadCount: unreadCount ?? this.unreadCount,
      updatedAt: updatedAt ?? this.updatedAt,
      context: context,
      peerId: peerId,
      peerName: peerName,
      productId: productId,
      sellerOrderId: sellerOrderId,
      lastSeenAt: lastSeenAt ?? this.lastSeenAt,
      isOnline: isOnline ?? this.isOnline,
    );
  }

  @override
  List<Object?> get props => [
        id,
        title,
        avatarUrl,
        lastMessage,
        unreadCount,
        updatedAt,
        context,
        peerId,
        peerName,
        productId,
        sellerOrderId,
        lastSeenAt,
        isOnline,
      ];
}
