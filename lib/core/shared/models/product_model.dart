// shared/models/product_model.dart

import '../entities/product.dart';
import 'product_media_model.dart';
import 'user_model.dart';

class ProductModel extends Product {
  const ProductModel({
    required super.id,
    required super.seller,
    required super.title,
    required super.description,
    required super.price,
    super.oldPrice,
    required super.media,
    required super.isAvailable,
    required super.isFeatured,
    required super.viewsCount,
    required super.likesCount,
    required super.createdAt,
  });

  factory ProductModel.fromJson(Map<String, dynamic> json) {
    return ProductModel(
      id: json['id'],

      seller: UserModel.fromJson(json['seller']),

      title: json['title'],
      description: json['description'],

      price: (json['price'] as num).toDouble(),

      oldPrice: json['old_price'] != null
          ? (json['old_price'] as num).toDouble()
          : null,

      media: (json['media'] as List)
          .map((e) => ProductMediaModel.fromJson(e))
          .toList(),

      isAvailable: json['is_available'] ?? true,
      isFeatured: json['is_featured'] ?? false,

      viewsCount: json['views_count'] ?? 0,
      likesCount: json['likes_count'] ?? 0,

      createdAt: DateTime.parse(json['created_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'seller': (seller as UserModel).toJson(),
      'title': title,
      'description': description,
      'price': price,
      'old_price': oldPrice,

      'media': media
          .map((e) => (e as ProductMediaModel).toJson())
          .toList(),

      'is_available': isAvailable,
      'is_featured': isFeatured,

      'views_count': viewsCount,
      'likes_count': likesCount,

      'created_at': createdAt.toIso8601String(),
    };
  }
}