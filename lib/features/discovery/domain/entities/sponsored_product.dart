import 'package:reem/core/shared/entities/product.dart';

/// A paid placement: the product it advertises, and the offer that paid.
///
/// Kept apart from ordinary results on purpose. A sponsored card must be
/// *shown* as sponsored, and carrying the paying offer is what lets a tap be
/// credited to the seller who bought the slot rather than to whoever else
/// happens to list the same product.
class SponsoredProduct {
  const SponsoredProduct({
    required this.product,
    required this.offerId,
    required this.placement,
  });

  final Product product;
  final String offerId;

  /// `search` or `category` — the page the slot was bought for.
  final String placement;
}
