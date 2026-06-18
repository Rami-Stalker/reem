import 'package:equatable/equatable.dart';
import 'package:reem/core/shared/entities/media.dart';
import 'package:reem/core/shared/entities/product_variant.dart';

import 'product_status.dart';

/// A product as seen by its owning seller — includes drafts/archived and the
/// full management surface (status, stock, variants, engagement counters).
class ManagedProduct extends Equatable {
  final String id;
  final String title;
  final String description;
  final String category;
  final double price;
  final double? oldPrice;
  final int stock;
  final ProductStatus status;
  final bool isFeatured;
  final bool showInFeed;
  final double rating;
  final int reviewsCount;
  final int viewsCount;
  final int likesCount;
  final int ordersCount;
  final int favoritesCount;
  final List<MediaItem> media;
  final List<ProductVariant> variants;
  final DateTime createdAt;

  const ManagedProduct({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    required this.price,
    this.oldPrice,
    this.stock = 0,
    this.status = ProductStatus.draft,
    this.isFeatured = false,
    this.showInFeed = true,
    this.rating = 0,
    this.reviewsCount = 0,
    this.viewsCount = 0,
    this.likesCount = 0,
    this.ordersCount = 0,
    this.favoritesCount = 0,
    this.media = const [],
    this.variants = const [],
    required this.createdAt,
  });

  String? get coverImage => media.isNotEmpty ? media.first.url : null;

  @override
  List<Object?> get props => [
        id,
        title,
        description,
        category,
        price,
        oldPrice,
        stock,
        status,
        isFeatured,
        showInFeed,
        rating,
        reviewsCount,
        viewsCount,
        likesCount,
        ordersCount,
        favoritesCount,
        media,
        variants,
        createdAt,
      ];
}

/// A page of managed products plus pagination metadata.
class ManagedProductPage {
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
}
