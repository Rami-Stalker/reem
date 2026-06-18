// shared/entities/product.dart

import 'package:equatable/equatable.dart';

import 'media.dart';
import 'product_variant.dart';
import 'user.dart';

class Product extends Equatable {
  final String id;
  final User seller;

  final String title;
  final String description;
  final String category;

  final double price;
  final double? oldPrice;

  final int stock;

  final List<MediaItem> media;
  final List<ProductVariant> variants;

  final bool isAvailable;
  final bool isFeatured;
  final bool isLiked;

  final double rating;
  final int reviewsCount;
  final int viewsCount;
  final int likesCount;
  final int ordersCount;
  final int favoritesCount;

  final DateTime createdAt;

  const Product({
    required this.id,
    required this.seller,
    required this.title,
    required this.description,
    this.category = 'general',
    required this.price,
    this.oldPrice,
    this.stock = 0,
    this.media = const [],
    this.variants = const [],
    this.isAvailable = true,
    this.isFeatured = false,
    this.isLiked = false,
    this.rating = 0,
    this.reviewsCount = 0,
    this.viewsCount = 0,
    this.likesCount = 0,
    this.ordersCount = 0,
    this.favoritesCount = 0,
    required this.createdAt,
  });

  /// First media item, if any.
  MediaItem? get cover => media.isNotEmpty ? media.first : null;
  String? get coverUrl => cover?.displayUrl;

  bool get inStock => stock > 0;
  bool get hasVariants => variants.isNotEmpty;

  bool get hasDiscount => oldPrice != null && oldPrice! > price;
  int get discountPercent =>
      hasDiscount ? (((oldPrice! - price) / oldPrice!) * 100).round() : 0;

  @override
  List<Object?> get props => [
        id,
        seller,
        title,
        description,
        category,
        price,
        oldPrice,
        stock,
        media,
        variants,
        isAvailable,
        isFeatured,
        isLiked,
        rating,
        reviewsCount,
        viewsCount,
        likesCount,
        ordersCount,
        favoritesCount,
        createdAt,
      ];
}
