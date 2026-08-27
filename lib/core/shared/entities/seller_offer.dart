// shared/entities/seller_offer.dart

import 'package:equatable/equatable.dart';
import 'package:reem/core/shared/entities/product_variant.dart';
import 'package:reem/core/shared/entities/user.dart';
import 'package:reem/core/shared/value_objects/money.dart';

enum OfferStatus {
  draft,
  pendingReview,
  active,
  outOfStock,
  paused,
  archived;

  static OfferStatus fromWire(String? value) =>
      switch (value?.toLowerCase().replaceAll('_', '')) {
        'pendingreview' => OfferStatus.pendingReview,
        'active' => OfferStatus.active,
        'outofstock' => OfferStatus.outOfStock,
        'paused' => OfferStatus.paused,
        'archived' => OfferStatus.archived,
        _ => OfferStatus.draft,
      };

  bool get isBuyable => this == OfferStatus.active;
}

/// One seller's listing of a canonical product.
///
/// This is the unit that actually gets bought: it holds the price, the
/// currency, the stock and the fulfilment terms. Several offers on the same
/// product are what makes price comparison possible (Q23) — the customer picks
/// a seller, not just a product.
class SellerOffer extends Equatable {
  final String id;
  final User seller;

  final Money price;

  /// The seller's own "was" price, for a strike-through.
  final Money? compareAtPrice;

  /// Wholesale tier for B2B accounts (Q35), with its minimum quantity.
  final Money? wholesalePrice;
  final int? wholesaleMinQty;

  final int stock;
  final int minOrderQty;
  final int? maxOrderQty;
  final String? sku;

  /// Days the seller needs before handing the parcel to a courier.
  final int handlingDays;

  /// Made-to-order goods — 3D prints, flower arrangements (Q30).
  final bool isMadeToOrder;
  final bool requiresDeposit;
  final bool acceptsReturns;

  final OfferStatus status;
  final List<OfferVariant> variants;

  const SellerOffer({
    required this.id,
    required this.seller,
    required this.price,
    this.compareAtPrice,
    this.wholesalePrice,
    this.wholesaleMinQty,
    this.stock = 0,
    this.minOrderQty = 1,
    this.maxOrderQty,
    this.sku,
    this.handlingDays = 1,
    this.isMadeToOrder = false,
    this.requiresDeposit = false,
    this.acceptsReturns = true,
    this.status = OfferStatus.draft,
    this.variants = const [],
  });

  Currency get currency => price.currency;

  bool get inStock => stock > 0;
  bool get isBuyable => status.isBuyable && inStock;
  bool get hasVariants => variants.isNotEmpty;

  bool get hasDiscount =>
      compareAtPrice != null &&
      compareAtPrice!.currency == price.currency &&
      compareAtPrice!.approximateValue > price.approximateValue;

  /// Only ever used for a badge — the charged amount comes from the server.
  int get discountPercent {
    if (!hasDiscount) return 0;
    final was = compareAtPrice!.approximateValue;
    return (((was - price.approximateValue) / was) * 100).round();
  }

  OfferVariant? variantById(String? id) {
    if (id == null) return null;
    for (final variant in variants) {
      if (variant.id == id) return variant;
    }
    return null;
  }

  @override
  List<Object?> get props => [
        id,
        seller,
        price,
        compareAtPrice,
        wholesalePrice,
        wholesaleMinQty,
        stock,
        minOrderQty,
        maxOrderQty,
        sku,
        handlingDays,
        isMadeToOrder,
        requiresDeposit,
        acceptsReturns,
        status,
        variants,
      ];
}
