import 'package:equatable/equatable.dart';
import 'package:ohara/core/shared/entities/product.dart';
import 'package:ohara/core/shared/entities/seller_offer.dart';
import 'package:ohara/core/shared/value_objects/money.dart';

/// The piece a message is about — «اسألي عن هذه القطعة».
///
/// Drawn above the text as a small card, the way a forwarded product looks
/// in WhatsApp, so the boutique reads *which* piece is being asked about
/// rather than guessing from "is it still available?". The server builds it
/// from the catalogue; the phone only says which product.
class ChatProductRef extends Equatable {
  const ChatProductRef({
    required this.id,
    required this.title,
    this.imageUrl,
    this.price,
  });

  /// The piece as she sees it on its page, priced at the offer she has
  /// selected — the boutique she is about to write to.
  factory ChatProductRef.of(Product product, {SellerOffer? offer}) =>
      ChatProductRef(
        id: product.id,
        title: product.title,
        imageUrl: product.coverUrl,
        price: (offer ?? product.bestOffer)?.price,
      );

  final String id;
  final String title;
  final String? imageUrl;

  /// The boutique's own live price, when she has one.
  final Money? price;

  @override
  List<Object?> get props => [id, title, imageUrl, price];
}

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

/// Where one of her own messages is on its way to the other side.
///
/// [sending] and [failed] exist only on the phone: a message is drawn the
/// moment she taps send, and the server's copy replaces it when it answers.
abstract final class ChatMessageStatus {
  static const sending = 'sending';
  static const failed = 'failed';
  static const sent = 'sent';
  static const delivered = 'delivered';
  static const read = 'read';
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
    this.status = ChatMessageStatus.sent,
    this.attachments = const [],
    this.deliveredAt,
    this.readAt,
    this.clientId,
    this.product,
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

  /// Chosen by the phone that sent it, before the server had an id to give.
  /// It is how the server's copy finds the optimistic one it replaces, and
  /// how a retry is recognised as the same message rather than a second one.
  final String? clientId;

  /// The piece this message asks about, when it was sent from a product.
  final ChatProductRef? product;

  bool get isImage => kind == 'image' || attachments.any((a) => a.kind == 'image');
  bool get isVoice => kind == 'voice' || attachments.any((a) => a.kind == 'voice');
  bool get isRead => status == ChatMessageStatus.read || readAt != null;
  bool get isDelivered =>
      status == ChatMessageStatus.delivered || isRead || deliveredAt != null;

  /// Drawn on her screen, not yet confirmed by the server.
  bool get isPending => status == ChatMessageStatus.sending;

  /// The server refused it or never answered; she can try again.
  bool get isFailed => status == ChatMessageStatus.failed;

  /// Only on this phone so far — pending or failed.
  bool get isLocal => isPending || isFailed;

  ChatMessageEntity copyWith({
    String? status,
    DateTime? deliveredAt,
    DateTime? readAt,
    bool? isMine,
  }) {
    return ChatMessageEntity(
      id: id,
      chatId: chatId,
      senderId: senderId,
      content: content,
      sentAt: sentAt,
      isMine: isMine ?? this.isMine,
      kind: kind,
      status: status ?? this.status,
      attachments: attachments,
      deliveredAt: deliveredAt ?? this.deliveredAt,
      readAt: readAt ?? this.readAt,
      clientId: clientId,
      product: product,
    );
  }

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
        product,
      ];
}
