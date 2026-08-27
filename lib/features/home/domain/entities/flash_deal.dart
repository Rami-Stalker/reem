import 'package:equatable/equatable.dart';

import 'package:reem/core/shared/entities/product.dart';

/// A time-boxed, limited-quantity offer. The price/discount live on [product];
/// this adds the urgency layer — a deadline and a stock-claimed meter.
class FlashDeal extends Equatable {
  const FlashDeal({
    required this.product,
    this.endsAt,
    required this.soldCount,
    required this.totalQuantity,
  });

  final Product product;
  /// When the discount stops.
  ///
  /// Null where the seller set no expiry, and the card then shows no timer at
  /// all — a countdown that resets on every refresh is a lie the customer
  /// notices exactly once.
  final DateTime? endsAt;
  final int soldCount;
  final int totalQuantity;

  /// Fraction of stock already claimed, clamped 0..1.
  double get claimedFraction =>
      totalQuantity <= 0 ? 0 : (soldCount / totalQuantity).clamp(0.0, 1.0);

  int get remainingQuantity =>
      (totalQuantity - soldCount).clamp(0, totalQuantity);

  /// Drives the "Almost gone!" urgency treatment.
  bool get isAlmostGone => claimedFraction >= 0.7;

  /// A deal with no expiry never ends — it is simply a lower price.
  bool get hasEnded {
    final at = endsAt;
    return at != null && DateTime.now().isAfter(at);
  }

  @override
  List<Object?> get props => [product, endsAt, soldCount, totalQuantity];
}
