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
    super.likesCount,
    super.ordersCount,
    super.favoritesCount,
    super.offersCount,
    super.media,
    super.variants,
    super.offerVariants,
  });

  /// Parses `GET /seller/offers` — an offer with its product nested inside.
  factory ManagedProductModel.fromJson(Map<String, dynamic> json) {
    final currency = Currency.fromWire(json['currency'] as String?);
    final product = (json['product'] as Map?)?.cast<String, dynamic>() ?? const {};

    return ManagedProductModel(
      id: json['id'] as String,
      productId: product['id'] as String? ?? '',
      title: product['title'] as String? ?? '',
      description: product['description'] as String? ?? '',
      category: product['category'] is Map
          ? CategoryModel.fromJson(
              (product['category'] as Map).cast<String, dynamic>())
          : CategoryModel.unknown,
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
      isFeatured: product['is_featured'] as bool? ?? false,
      showInFeed: product['show_in_feed'] as bool? ?? true,
      rating: (product['rating'] as num?)?.toDouble() ?? 0,
      reviewsCount: product['reviews_count'] as int? ?? 0,
      viewsCount: product['views_count'] as int? ?? 0,
      likesCount: product['likes_count'] as int? ?? 0,
      ordersCount: product['orders_count'] as int? ?? 0,
      favoritesCount: product['favorites_count'] as int? ?? 0,
      offersCount: product['offers_count'] as int? ?? 1,
      media: (product['media'] as List? ?? [])
          .map((e) => MediaModel.fromJson(e as Map<String, dynamic>))
          .toList(),
      variants: (product['variants'] as List? ?? [])
          .map((e) => ProductVariantModel.fromJson(e as Map<String, dynamic>))
          .toList(),
      offerVariants: (json['variants'] as List? ?? [])
          .map((e) => OfferVariantModel.fromJson(
                e as Map<String, dynamic>,
                fallbackCurrency: currency,
              ))
          .toList(),
      createdAt: DateTime.tryParse(product['created_at'] as String? ?? '') ??
          DateTime.now(),
    );
  }
}
