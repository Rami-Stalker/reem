// shared/models/product_model.dart

import 'package:reem/core/shared/entities/brand.dart';
import 'package:reem/core/shared/entities/category.dart';
import 'package:reem/core/shared/entities/media.dart';
import 'package:reem/core/shared/entities/product.dart';
import 'package:reem/core/shared/entities/product_variant.dart';
import 'package:reem/core/shared/entities/seller_offer.dart';
import 'package:reem/core/shared/models/brand_model.dart';
import 'package:reem/core/shared/models/category_model.dart';
import 'package:reem/core/shared/models/media_model.dart';
import 'package:reem/core/shared/models/product_variant_model.dart';
import 'package:reem/core/shared/models/seller_offer_model.dart';
import 'package:reem/core/shared/value_objects/money.dart';

class ProductModel extends Product {
  const ProductModel({
    required super.id,
    required super.slug,
    required super.title,
    required super.description,
    required super.category,
    required super.createdAt,
    super.brand,
    super.attributes,
    super.gtin,
    super.media,
    super.variants,
    super.offers,
    super.offersCount,
    super.priceFrom,
    super.priceTo,
    super.stock,
    super.isLiked,
    super.rating,
    super.reviewsCount,
    super.viewsCount,
    super.likesCount,
    super.ordersCount,
    super.favoritesCount,
  });

  factory ProductModel.fromJson(Map<String, dynamic> json) {
    // A card carries `best_offer` only; the detail screen also carries the full
    // `offers` list. Normalising both into one list here means every widget
    // reads offers the same way regardless of which endpoint produced it.
    final offers = <SellerOffer>[
      ...(json['offers'] as List? ?? const [])
          .map((e) => SellerOfferModel.fromJson(e as Map<String, dynamic>)),
    ];
    if (offers.isEmpty && json['best_offer'] != null) {
      offers.add(
        SellerOfferModel.fromJson(json['best_offer'] as Map<String, dynamic>),
      );
    }

    final categoryJson = json['category'];
    return ProductModel(
      id: json['id'] as String,
      slug: json['slug'] as String? ?? '',
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      category: categoryJson is Map<String, dynamic>
          ? CategoryModel.fromJson(categoryJson)
          : CategoryModel.unknown,
      brand: json['brand'] is Map<String, dynamic>
          ? BrandModel.fromJson(json['brand'] as Map<String, dynamic>)
          : null,
      attributes: (json['attributes'] as Map?)?.cast<String, dynamic>() ?? {},
      gtin: json['gtin'] as String?,
      media: (json['media'] as List? ?? [])
          .map((e) => MediaModel.fromJson(e as Map<String, dynamic>))
          .toList(),
      variants: (json['variants'] as List? ?? [])
          .map((e) => ProductVariantModel.fromJson(e as Map<String, dynamic>))
          .toList(),
      offers: offers,
      offersCount: json['offers_count'] as int? ?? offers.length,
      priceFrom: Money.tryFromJson(json['price_from']),
      priceTo: Money.tryFromJson(json['price_to']),
      stock: json['stock'] as int? ?? 0,
      isLiked: json['is_liked'] as bool? ?? false,
      rating: (json['rating'] as num?)?.toDouble() ?? 0,
      reviewsCount: json['reviews_count'] as int? ?? 0,
      viewsCount: json['views_count'] as int? ?? 0,
      likesCount: json['likes_count'] as int? ?? 0,
      ordersCount: json['orders_count'] as int? ?? 0,
      favoritesCount: json['favorites_count'] as int? ?? 0,
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ??
          DateTime.now(),
    );
  }

  factory ProductModel.fromEntity(Product p) => ProductModel(
        id: p.id,
        slug: p.slug,
        title: p.title,
        description: p.description,
        category: p.category,
        brand: p.brand,
        attributes: p.attributes,
        gtin: p.gtin,
        media: p.media,
        variants: p.variants,
        offers: p.offers,
        offersCount: p.offersCount,
        priceFrom: p.priceFrom,
        priceTo: p.priceTo,
        stock: p.stock,
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
        'slug': slug,
        'title': title,
        'description': description,
        'category': CategoryModel.fromEntity(category).toJson(),
        'brand': brand == null ? null : BrandModel.fromEntity(brand!).toJson(),
        'attributes': attributes,
        'gtin': gtin,
        'media': media.map((m) => MediaModel.fromEntity(m).toJson()).toList(),
        'variants': variants
            .map((v) => ProductVariantModel.fromEntity(v).toJson())
            .toList(),
        'offers': offers
            .map((o) => SellerOfferModel.fromEntity(o).toJson())
            .toList(),
        'offers_count': offersCount,
        'price_from': priceFrom?.toJson(),
        'price_to': priceTo?.toJson(),
        'stock': stock,
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
    String? slug,
    String? title,
    String? description,
    Category? category,
    Brand? brand,
    Map<String, dynamic>? attributes,
    String? gtin,
    List<MediaItem>? media,
    List<ProductVariant>? variants,
    List<SellerOffer>? offers,
    int? offersCount,
    Money? priceFrom,
    Money? priceTo,
    int? stock,
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
      slug: slug ?? this.slug,
      title: title ?? this.title,
      description: description ?? this.description,
      category: category ?? this.category,
      brand: brand ?? this.brand,
      attributes: attributes ?? this.attributes,
      gtin: gtin ?? this.gtin,
      media: media ?? this.media,
      variants: variants ?? this.variants,
      offers: offers ?? this.offers,
      offersCount: offersCount ?? this.offersCount,
      priceFrom: priceFrom ?? this.priceFrom,
      priceTo: priceTo ?? this.priceTo,
      stock: stock ?? this.stock,
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
