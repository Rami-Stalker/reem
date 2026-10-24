import 'package:equatable/equatable.dart';
import 'package:ohara/core/shared/entities/product.dart';
import 'package:ohara/core/shared/value_objects/money.dart';

/// What she did with a card. Mirrors the server enum exactly, because these
/// values travel back as-is.
enum StylistFeedback {
  none,
  liked,
  saved,
  dismissed,
  addedToCart,
  purchased;

  static StylistFeedback fromWire(String? value) => switch (value) {
        'LIKED' => StylistFeedback.liked,
        'SAVED' => StylistFeedback.saved,
        'DISMISSED' => StylistFeedback.dismissed,
        'ADDED_TO_CART' => StylistFeedback.addedToCart,
        'PURCHASED' => StylistFeedback.purchased,
        _ => StylistFeedback.none,
      };

  String get wire => switch (this) {
        StylistFeedback.none => 'NONE',
        StylistFeedback.liked => 'LIKED',
        StylistFeedback.saved => 'SAVED',
        StylistFeedback.dismissed => 'DISMISSED',
        StylistFeedback.addedToCart => 'ADDED_TO_CART',
        StylistFeedback.purchased => 'PURCHASED',
      };
}

/// One product the stylist put forward, and the sentence explaining why.
///
/// The [product] is the ordinary catalogue [Product] — the same entity search
/// and discovery hand to their cards — so a recommendation renders with the
/// widgets the app already has. Everything else here is what the stylist adds
/// on top: the reason, the slot it fills, and the price it was quoted at.
class StylistRecommendation extends Equatable {
  final String id;
  final Product product;
  final String? offerId;

  /// Set when the card is a piece of a look rather than a list entry.
  final String? slot;
  final String? slotLabel;

  final double score;
  final int position;

  /// The customer-facing justification, rendered server-side from the score
  /// components that actually fired.
  final String reason;

  /// The machine-readable version of [reason]. Kept so the UI can highlight a
  /// particular kind of match without parsing Arabic prose.
  final List<String> reasonCodes;

  /// Frozen when the card was produced, so a later price change does not
  /// silently rewrite what she was shown.
  final Money? quotedPrice;

  final StylistFeedback feedback;
  final DateTime createdAt;

  const StylistRecommendation({
    required this.id,
    required this.product,
    required this.reason,
    required this.createdAt,
    this.offerId,
    this.slot,
    this.slotLabel,
    this.score = 0,
    this.position = 0,
    this.reasonCodes = const [],
    this.quotedPrice,
    this.feedback = StylistFeedback.none,
  });

  bool get isDismissed => feedback == StylistFeedback.dismissed;
  bool get isLiked => feedback == StylistFeedback.liked;

  /// The price to show. The quote wins when present: it is what she was
  /// actually offered.
  Money? get displayPrice => quotedPrice ?? product.price ?? product.priceFrom;

  bool get inStock => product.inStock;

  StylistRecommendation copyWith({StylistFeedback? feedback}) {
    return StylistRecommendation(
      id: id,
      product: product,
      reason: reason,
      createdAt: createdAt,
      offerId: offerId,
      slot: slot,
      slotLabel: slotLabel,
      score: score,
      position: position,
      reasonCodes: reasonCodes,
      quotedPrice: quotedPrice,
      feedback: feedback ?? this.feedback,
    );
  }

  @override
  List<Object?> get props => [id, product, slot, score, reason, feedback];
}
