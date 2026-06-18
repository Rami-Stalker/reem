import 'package:reem/core/shared/models/media_model.dart';
import 'package:reem/core/shared/models/product_variant_model.dart';

import '../../domain/entities/managed_product.dart';
import '../../domain/entities/product_status.dart';

class ManagedProductModel extends ManagedProduct {
  const ManagedProductModel({
    required super.id,
    required super.title,
    required super.description,
    required super.category,
    required super.price,
    super.oldPrice,
    super.stock,
    super.status,
    super.isFeatured,
    super.showInFeed,
    super.rating,
    super.reviewsCount,
    super.viewsCount,
    super.likesCount,
    super.ordersCount,
    super.favoritesCount,
    super.media,
    super.variants,
    required super.createdAt,
  });

  factory ManagedProductModel.fromJson(Map<String, dynamic> json) {
    return ManagedProductModel(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String? ?? '',
      category: json['category'] as String? ?? 'general',
      price: (json['price'] as num).toDouble(),
      oldPrice: (json['old_price'] as num?)?.toDouble(),
      stock: json['stock'] as int? ?? 0,
      status: ProductStatusX.fromWire(json['status'] as String?),
      isFeatured: json['is_featured'] as bool? ?? false,
      showInFeed: json['show_in_feed'] as bool? ?? true,
      rating: (json['rating'] as num?)?.toDouble() ?? 0,
      reviewsCount: json['reviews_count'] as int? ?? 0,
      viewsCount: json['views_count'] as int? ?? 0,
      likesCount: json['likes_count'] as int? ?? 0,
      ordersCount: json['orders_count'] as int? ?? 0,
      favoritesCount: json['favorites_count'] as int? ?? 0,
      media: (json['media'] as List? ?? [])
          .map((e) => MediaModel.fromJson(e as Map<String, dynamic>))
          .toList(),
      variants: (json['variants'] as List? ?? [])
          .map((e) => ProductVariantModel.fromJson(e as Map<String, dynamic>))
          .toList(),
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}
