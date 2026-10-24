import 'package:equatable/equatable.dart';

import 'package:ohara/core/shared/value_objects/money.dart';

/// A single line in the cart.
///
/// A line points at a seller's **offer**, not at a product: the same product
/// may be listed by several sellers at different prices, so "what am I buying"
/// is only answered by naming whose listing it came from.
class CartLine extends Equatable {
  final String id;
  final String offerId;

  final String sellerId;
  final String sellerName;
  final String? sellerImageUrl;

  final String productId;
  final String title;
  final String? image;
  final String categorySlug;

  /// Whether this line is eligible for a change-of-mind return — the category
  /// and the seller's own policy both have to allow it.
  final bool returnsAllowed;

  final String? offerVariantId;
  final String? variantName;

  final int quantity;
  final Money unitPrice;
  final Money lineTotal;

  final bool inStock;
  final int availableStock;
  final int minOrderQty;
  final int? maxOrderQty;

  /// Made-to-order goods take longer and are usually non-returnable (Q30).
  final bool isMadeToOrder;
  final int handlingDays;

  const CartLine({
    required this.id,
    required this.offerId,
    required this.sellerId,
    required this.sellerName,
    required this.productId,
    required this.title,
    required this.quantity,
    required this.unitPrice,
    required this.lineTotal,
    required this.inStock,
    required this.availableStock,
    this.sellerImageUrl,
    this.image,
    this.categorySlug = '',
    this.returnsAllowed = true,
    this.offerVariantId,
    this.variantName,
    this.minOrderQty = 1,
    this.maxOrderQty,
    this.isMadeToOrder = false,
    this.handlingDays = 1,
  });

  Currency get currency => unitPrice.currency;

  bool get canIncrement =>
      quantity < availableStock &&
      (maxOrderQty == null || quantity < maxOrderQty!);

  bool get canDecrement => quantity > minOrderQty;

  @override
  List<Object?> get props => [
        id,
        offerId,
        sellerId,
        productId,
        offerVariantId,
        quantity,
        unitPrice,
        lineTotal,
        inStock,
        availableStock,
      ];
}

/// The lines belonging to one seller.
///
/// The basket is grouped this way because that is how it will be fulfilled:
/// each seller becomes its own sub-order with its own parcel, its own status
/// and its own timeline (Q40/Q65).
class CartSellerGroup extends Equatable {
  final String sellerId;
  final String sellerName;
  final String? sellerImageUrl;
  final List<String> itemIds;
  final int itemsCount;

  /// Null when this seller's lines are priced in more than one currency,
  /// which the client refuses to add up.
  final Money? subtotal;

  const CartSellerGroup({
    required this.sellerId,
    required this.sellerName,
    this.sellerImageUrl,
    this.itemIds = const [],
    this.itemsCount = 0,
    this.subtotal,
  });

  @override
  List<Object?> get props =>
      [sellerId, sellerName, itemIds, itemsCount, subtotal];
}

/// Basket totals.
///
/// There is deliberately no single `total` here. The charged total needs the
/// coupon, the shipping quote and a frozen exchange rate, and all three belong
/// to checkout — the previous version hardcoded `total = subtotal`, so the cart
/// and the checkout screen quoted different numbers to the same customer.
class CartSummary extends Equatable {
  final List<Money> subtotalsByCurrency;
  final int itemsCount;
  final int sellersCount;
  final int totalQuantity;

  const CartSummary({
    this.subtotalsByCurrency = const [],
    this.itemsCount = 0,
    this.sellersCount = 0,
    this.totalQuantity = 0,
  });

  /// The headline figure — the SYP subtotal when there is one.
  Money? get subtotal => subtotalsByCurrency.primary;

  bool get isMultiCurrency => subtotalsByCurrency.length > 1;

  @override
  List<Object?> get props =>
      [subtotalsByCurrency, itemsCount, sellersCount, totalQuantity];
}

class Cart extends Equatable {
  final List<CartLine> items;
  final List<CartSellerGroup> sellerGroups;
  final CartSummary summary;

  const Cart({
    this.items = const [],
    this.sellerGroups = const [],
    this.summary = const CartSummary(),
  });

  bool get isEmpty => items.isEmpty;
  bool get hasOutOfStock => items.any((line) => !line.inStock);

  /// True when this basket will arrive as more than one parcel — worth telling
  /// the customer before checkout rather than after (Q89).
  bool get willSplit => sellerGroups.length > 1;

  List<CartLine> linesFor(CartSellerGroup group) =>
      items.where((line) => line.sellerId == group.sellerId).toList();

  @override
  List<Object?> get props => [items, sellerGroups, summary];
}
