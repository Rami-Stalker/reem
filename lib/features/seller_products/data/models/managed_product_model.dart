import 'package:reem/core/shared/models/category_model.dart';
import 'package:reem/core/shared/models/media_model.dart';
import 'package:reem/core/shared/models/product_variant_model.dart';
import 'package:reem/core/shared/value_objects/money.dart';

import 'package:reem/features/seller_products/domain/entities/managed_product.dart';
import 'package:reem/features/seller_products/domain/entities/product_status.dart';

class ManagedProductModel extends ManagedProduct {
  const ManagedProductModel({
    required super.id,
    required super.productId,
    required super.title,
    required super.description,
    required super.category,
    required super.price,
    super.attributes,
    required super.createdAt,
    super.compareAtPrice,
    super.stock,
    super.minOrderQty,
    super.maxOrderQty,
    super.sku,
    super.handlingDays,
    super.isMadeToOrder,
    super.acceptsReturns,
    super.status,
    super.isFeatured,
    super.showInFeed,
    super.rating,
    super.reviewsCount,
    super.viewsCount,
    super.ordersCount,
    super.favoritesCount,
    super.offersCount,
    super.media,
    super.variants,
    super.offerVariants,
  });

  /// Parses an offer with its product nested inside — `GET /seller/offers`,
  /// `GET /seller/offers/:id`, and `/seller/offers/low-stock`.
  ///
  /// `PATCH /seller/offers/:id` and `POST /seller/offers/:id/stock` serialise
  /// the offer ALONE, with no product beside it, because nothing about the
  /// shared entry can have changed. [fallbackProduct] supplies the title,
  /// gallery and category in that case so a publish or a restock does not
  /// hand back a listing with a blank name.
  factory ManagedProductModel.fromJson(
    Map<String, dynamic> json, {
    ManagedProduct? fallbackProduct,
  }) {
    final currency = Currency.fromWire(json['currency'] as String?);
    final product =
        (json['product'] as Map?)?.cast<String, dynamic>() ?? const {};
    final prior = fallbackProduct;

    return ManagedProductModel(
      id: json['id'] as String,
      productId: product['id'] as String? ?? prior?.productId ?? '',
      title: product['title'] as String? ?? prior?.title ?? '',
      description: product['description'] as String? ?? prior?.description ?? '',
      category: product['category'] is Map
          ? CategoryModel.fromJson(
              (product['category'] as Map).cast<String, dynamic>())
          : prior?.category ?? CategoryModel.unknown,
      attributes: product['attributes'] is Map
          ? (product['attributes'] as Map).cast<String, dynamic>()
          : prior?.attributes ?? const {},
      price: Money.fromJson(json['price'], fallback: currency),
      compareAtPrice:
          Money.tryFromJson(json['compare_at_price'], fallback: currency),
      stock: json['stock'] as int? ?? 0,
      minOrderQty: json['min_order_qty'] as int? ?? 1,
      maxOrderQty: json['max_order_qty'] as int?,
      sku: json['sku'] as String?,
      handlingDays: json['handling_days'] as int? ?? 1,
      isMadeToOrder: json['is_made_to_order'] as bool? ?? false,
      acceptsReturns: json['accepts_returns'] as bool? ?? true,
      status: ProductStatusX.fromWire(json['status'] as String?),
      isFeatured: product['is_featured'] as bool? ?? prior?.isFeatured ?? false,
      showInFeed: product['show_in_feed'] as bool? ?? prior?.showInFeed ?? true,
      rating: (product['rating'] as num?)?.toDouble() ?? prior?.rating ?? 0,
      reviewsCount: product['reviews_count'] as int? ?? prior?.reviewsCount ?? 0,
      viewsCount: product['views_count'] as int? ?? prior?.viewsCount ?? 0,
      ordersCount: product['orders_count'] as int? ?? prior?.ordersCount ?? 0,
      favoritesCount:
          product['favorites_count'] as int? ?? prior?.favoritesCount ?? 0,
      offersCount: product['offers_count'] as int? ?? prior?.offersCount ?? 1,
      media: product['media'] is List
          ? (product['media'] as List)
              .map((e) => MediaModel.fromJson(e as Map<String, dynamic>))
              .toList()
          : prior?.media ?? const [],
      variants: product['variants'] is List
          ? (product['variants'] as List)
              .map(
                (e) => ProductVariantModel.fromJson(e as Map<String, dynamic>),
              )
              .toList()
          : prior?.variants ?? const [],
      offerVariants: (json['variants'] as List? ?? [])
          .map((e) => OfferVariantModel.fromJson(
                e as Map<String, dynamic>,
                fallbackCurrency: currency,
              ))
          .toList(),
      createdAt: DateTime.tryParse(product['created_at'] as String? ?? '') ??
          prior?.createdAt ??
          DateTime.now(),
    );
  }

  /// Parses `POST /seller/products`, which answers with the canonical entry it
  /// just created and the seller's own listing on it under `my_offer` — the
  /// mirror image of every other seller-catalogue payload, where the offer is
  /// the envelope and the product the passenger.
  factory ManagedProductModel.fromCreateResponse(Map<String, dynamic> json) {
    final offer = (json['my_offer'] as Map?)?.cast<String, dynamic>();
    if (offer == null) {
      throw const FormatException(
        'Product was created without an offer on it — nothing to manage.',
      );
    }

    final product = Map<String, dynamic>.from(json)..remove('my_offer');
    return ManagedProductModel.fromJson({...offer, 'product': product});
  }
}
