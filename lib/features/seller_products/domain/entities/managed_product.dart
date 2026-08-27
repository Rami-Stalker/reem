import 'package:equatable/equatable.dart';
import 'package:reem/core/shared/entities/category.dart';
import 'package:reem/core/shared/entities/media.dart';
import 'package:reem/core/shared/entities/product_variant.dart';

import 'product_status.dart';
import 'package:reem/core/shared/value_objects/money.dart';

/// A seller's own listing.
///
/// The seller does not own a catalogue entry — several sellers may list the
/// same product. What they own is the *offer*: its price, currency, stock and
/// fulfilment terms. So this is an offer joined to the product it points at,
/// which is exactly what `GET /seller/offers` returns.
class ManagedProduct extends Equatable {
  /// The offer id — the handle for every seller-side mutation.
  final String id;

  /// The canonical catalogue entry this offer sits on.
  final String productId;
  final String title;
  final String description;
  final Category category;

  final Money price;
  final Money? compareAtPrice;
  final int stock;
  final int minOrderQty;
  final int? maxOrderQty;
  final String? sku;
  final int handlingDays;
  final bool isMadeToOrder;
  final bool acceptsReturns;

  final ProductStatus status;

  /// Curation flags — set by the platform, shown to the seller read-only.
  final bool isFeatured;
  final bool showInFeed;

  /// Engagement lives on the shared catalogue entry, not on one seller's offer.
  final double rating;
  final int reviewsCount;
  final int viewsCount;
  final int likesCount;
  final int ordersCount;
  final int favoritesCount;

  /// How many sellers list this product, so the seller can see their
  /// competition at a glance.
  final int offersCount;

  final List<MediaItem> media;
  final List<ProductVariant> variants;
  final List<OfferVariant> offerVariants;
  final DateTime createdAt;

  const ManagedProduct({
    required this.id,
    required this.productId,
    required this.title,
    required this.description,
    required this.category,
    required this.price,
    required this.createdAt,
    this.compareAtPrice,
    this.stock = 0,
    this.minOrderQty = 1,
    this.maxOrderQty,
    this.sku,
    this.handlingDays = 1,
    this.isMadeToOrder = false,
    this.acceptsReturns = true,
    this.status = ProductStatus.draft,
    this.isFeatured = false,
    this.showInFeed = true,
    this.rating = 0,
    this.reviewsCount = 0,
    this.viewsCount = 0,
    this.likesCount = 0,
    this.ordersCount = 0,
    this.favoritesCount = 0,
    this.offersCount = 1,
    this.media = const [],
    this.variants = const [],
    this.offerVariants = const [],
  });

  String? get coverImage => media.isNotEmpty ? media.first.url : null;

  Currency get currency => price.currency;
  bool get inStock => stock > 0;
  bool get isLive => status.isLive && inStock;

  /// True when a competitor also lists this product.
  bool get hasCompetition => offersCount > 1;

  @override
  List<Object?> get props => [
        id,
        productId,
        title,
        description,
        category,
        price,
        compareAtPrice,
        stock,
        minOrderQty,
        maxOrderQty,
        sku,
        handlingDays,
        isMadeToOrder,
        acceptsReturns,
        status,
        isFeatured,
        showInFeed,
        rating,
        reviewsCount,
        viewsCount,
        likesCount,
        ordersCount,
        favoritesCount,
        offersCount,
        media,
        variants,
        offerVariants,
        createdAt,
      ];
}

/// One page of the seller's listings.
class ManagedProductPage extends Equatable {
  final List<ManagedProduct> items;
  final int page;
  final int totalPages;
  final bool hasNextPage;

  const ManagedProductPage({
    required this.items,
    required this.page,
    required this.totalPages,
    required this.hasNextPage,
  });

  @override
  List<Object?> get props => [items, page, totalPages, hasNextPage];
}
