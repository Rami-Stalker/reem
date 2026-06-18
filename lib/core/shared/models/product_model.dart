// shared/models/product_model.dart

import '../entities/media.dart';
import '../entities/product.dart';
import '../entities/product_variant.dart';
import '../entities/user.dart';
import 'media_model.dart';
import 'product_variant_model.dart';
import 'user_model.dart';

class ProductModel extends Product {
  const ProductModel({
    required super.id,
    required super.seller,
    required super.title,
    required super.description,
    super.category,
    required super.price,
    super.oldPrice,
    super.stock,
    super.media,
    super.variants,
    super.isAvailable,
    super.isFeatured,
    super.isLiked,
    super.rating,
    super.reviewsCount,
    super.viewsCount,
    super.likesCount,
    super.ordersCount,
    super.favoritesCount,
    required super.createdAt,
  });

  factory ProductModel.fromJson(Map<String, dynamic> json) {
    return ProductModel(
      id: json['id'] as String,
      seller: UserModel.fromJson(json['seller'] as Map<String, dynamic>),
      title: json['title'] as String,
      description: json['description'] as String? ?? '',
      category: json['category'] as String? ?? 'general',
      price: (json['price'] as num).toDouble(),
      oldPrice: (json['old_price'] as num?)?.toDouble(),
      stock: json['stock'] as int? ?? 0,
      media: (json['media'] as List? ?? [])
          .map((e) => MediaModel.fromJson(e as Map<String, dynamic>))
          .toList(),
      variants: (json['variants'] as List? ?? [])
          .map((e) => ProductVariantModel.fromJson(e as Map<String, dynamic>))
          .toList(),
      isAvailable: json['is_available'] as bool? ?? true,
      isFeatured: json['is_featured'] as bool? ?? false,
      isLiked: json['is_liked'] as bool? ?? false,
      rating: (json['rating'] as num?)?.toDouble() ?? 0,
      reviewsCount: json['reviews_count'] as int? ?? 0,
      viewsCount: json['views_count'] as int? ?? 0,
      likesCount: json['likes_count'] as int? ?? 0,
      ordersCount: json['orders_count'] as int? ?? 0,
      favoritesCount: json['favorites_count'] as int? ?? 0,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  factory ProductModel.fromEntity(Product p) => ProductModel(
        id: p.id,
        seller: p.seller,
        title: p.title,
        description: p.description,
        category: p.category,
        price: p.price,
        oldPrice: p.oldPrice,
        stock: p.stock,
        media: p.media,
        variants: p.variants,
        isAvailable: p.isAvailable,
        isFeatured: p.isFeatured,
        isLiked: p.isLiked,
        rating: p.rating,
        reviewsCount: p.reviewsCount,
        viewsCount: p.viewsCount,
        likesCount: p.likesCount,
        ordersCount: p.ordersCount,
        favoritesCount: p.favoritesCount,
        createdAt: p.createdAt,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'seller': UserModel.fromEntity(seller).toJson(),
        'title': title,
        'description': description,
        'category': category,
        'price': price,
        'old_price': oldPrice,
        'stock': stock,
        'media': media.map((m) => MediaModel.fromEntity(m).toJson()).toList(),
        'variants': variants
            .map((v) => ProductVariantModel(
                  id: v.id,
                  name: v.name,
                  sku: v.sku,
                  price: v.price,
                  stock: v.stock,
                  sortOrder: v.sortOrder,
                ).toJson())
            .toList(),
        'is_available': isAvailable,
        'is_featured': isFeatured,
        'is_liked': isLiked,
        'rating': rating,
        'reviews_count': reviewsCount,
        'views_count': viewsCount,
        'likes_count': likesCount,
        'orders_count': ordersCount,
        'favorites_count': favoritesCount,
        'created_at': createdAt.toIso8601String(),
      };

  ProductModel copyWith({
    String? id,
    User? seller,
    String? title,
    String? description,
    String? category,
    double? price,
    double? oldPrice,
    int? stock,
    List<MediaItem>? media,
    List<ProductVariant>? variants,
    bool? isAvailable,
    bool? isFeatured,
    bool? isLiked,
    double? rating,
    int? reviewsCount,
    int? viewsCount,
    int? likesCount,
    int? ordersCount,
    int? favoritesCount,
    DateTime? createdAt,
  }) {
    return ProductModel(
      id: id ?? this.id,
      seller: seller ?? this.seller,
      title: title ?? this.title,
      description: description ?? this.description,
      category: category ?? this.category,
      price: price ?? this.price,
      oldPrice: oldPrice ?? this.oldPrice,
      stock: stock ?? this.stock,
      media: media ?? this.media,
      variants: variants ?? this.variants,
      isAvailable: isAvailable ?? this.isAvailable,
      isFeatured: isFeatured ?? this.isFeatured,
      isLiked: isLiked ?? this.isLiked,
      rating: rating ?? this.rating,
      reviewsCount: reviewsCount ?? this.reviewsCount,
      viewsCount: viewsCount ?? this.viewsCount,
      likesCount: likesCount ?? this.likesCount,
      ordersCount: ordersCount ?? this.ordersCount,
      favoritesCount: favoritesCount ?? this.favoritesCount,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
