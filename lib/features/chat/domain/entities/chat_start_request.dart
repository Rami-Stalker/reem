/// What a conversation is being opened *about*.
///
/// The server resolves the pair of people from this, and reuses an existing
/// thread when one already matches — so a second tap on «راسلي البائعة» reopens
/// the same conversation rather than starting a parallel one.
///
/// The three constructors are the three shapes the server accepts. Modelling
/// them as named constructors rather than a bag of optional ids means the
/// combination that gets rejected at the far end cannot be written here.
sealed class ChatStartRequest {
  const ChatStartRequest({this.openingMessage});

  /// A question about one product. [sellerId] picks which of the product's
  /// sellers to ask — omit it and the server picks the cheapest offer's seller.
  const factory ChatStartRequest.product({
    required String productId,
    String? sellerId,
    String? openingMessage,
  }) = ChatStartProduct;

  /// A question about one seller's parcel. Takes the *seller order* id — the
  /// per-seller parcel — not the umbrella order id.
  const factory ChatStartRequest.order({
    required String sellerOrderId,
    String? openingMessage,
  }) = ChatStartOrder;

  /// A conversation with a person, about nothing in particular. Only ever
  /// buyer↔seller; the server refuses any other pairing.
  const factory ChatStartRequest.peer({
    required String peerId,
    String? openingMessage,
  }) = ChatStartPeer;

  /// Sent as the first message the moment the thread exists. Optional: opening
  /// an empty conversation and letting her type is the common case.
  final String? openingMessage;

  Map<String, dynamic> toJson();

  Map<String, dynamic> _withMessage(Map<String, dynamic> body) {
    final message = openingMessage?.trim();
    return {
      ...body,
      if (message != null && message.isNotEmpty) 'message': message,
    };
  }
}

final class ChatStartProduct extends ChatStartRequest {
  const ChatStartProduct({
    required this.productId,
    this.sellerId,
    super.openingMessage,
  });

  final String productId;
  final String? sellerId;

  @override
  Map<String, dynamic> toJson() => _withMessage({
        'type': 'PRODUCT',
        'product_id': productId,
        if (sellerId != null) 'seller_id': sellerId,
      });
}

final class ChatStartOrder extends ChatStartRequest {
  const ChatStartOrder({required this.sellerOrderId, super.openingMessage});

  final String sellerOrderId;

  @override
  Map<String, dynamic> toJson() => _withMessage({
        'type': 'ORDER',
        'order_id': sellerOrderId,
      });
}

final class ChatStartPeer extends ChatStartRequest {
  const ChatStartPeer({required this.peerId, super.openingMessage});

  final String peerId;

  @override
  Map<String, dynamic> toJson() => _withMessage({
        'type': 'DIRECT',
        'participant_id': peerId,
      });
}
