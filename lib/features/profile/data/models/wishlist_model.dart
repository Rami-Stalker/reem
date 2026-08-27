import 'package:reem/core/shared/models/post_model.dart';
import 'package:reem/core/shared/models/product_model.dart';
import 'package:reem/core/shared/models/user_model.dart';

import 'package:reem/features/profile/domain/entities/wishlist_entity.dart';

class SavedSellerModel extends SavedSeller {
  const SavedSellerModel({required super.seller, required super.savedAt});

  factory SavedSellerModel.fromJson(Map<String, dynamic> json) {
    return SavedSellerModel(
      seller: UserModel.fromJson(
        Map<String, dynamic>.from(json['seller'] as Map),
      ),
      savedAt: DateTime.parse(json['saved_at'] as String),
    );
  }
}

class SavedPostModel extends SavedPost {
  const SavedPostModel({required super.post, required super.savedAt});

  factory SavedPostModel.fromJson(Map<String, dynamic> json) {
    return SavedPostModel(
      post: PostModel.fromJson(Map<String, dynamic>.from(json['post'] as Map)),
      savedAt: DateTime.parse(json['saved_at'] as String),
    );
  }
}

class WishlistItemModel extends WishlistItem {
  const WishlistItemModel({
    required super.id,
    required super.type,
    super.product,
    super.seller,
    super.post,
    super.priceWhenSaved,
    super.notifyPriceDrop,
    super.notifyBackInStock,
    super.note,
    required super.createdAt,
  });

  factory WishlistItemModel.fromJson(Map<String, dynamic> json) {
    final product = json['product'];
    final seller = json['seller'];
    final post = json['post'];
    return WishlistItemModel(
      id: json['id'] as String,
      type: json['type'] as String? ?? 'product',
      product: product is Map
          ? ProductModel.fromJson(Map<String, dynamic>.from(product))
          : null,
      seller: seller is Map
          ? UserModel.fromJson(Map<String, dynamic>.from(seller))
          : null,
      post: post is Map
          ? PostModel.fromJson(Map<String, dynamic>.from(post))
          : null,
      priceWhenSaved: (json['price_when_saved'] as num?)?.toDouble(),
      notifyPriceDrop: json['notify_price_drop'] as bool? ?? true,
      notifyBackInStock: json['notify_back_in_stock'] as bool? ?? true,
      note: json['note'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}

class WishlistCollectionModel extends WishlistCollection {
  const WishlistCollectionModel({
    required super.id,
    required super.name,
    super.description,
    required super.visibility,
    super.shareSlug,
    super.itemsCount,
    super.items,
    required super.createdAt,
    required super.updatedAt,
  });

  factory WishlistCollectionModel.fromJson(Map<String, dynamic> json) {
    return WishlistCollectionModel(
      id: json['id'] as String,
      name: json['name'] as String? ?? 'Wishlist',
      description: json['description'] as String?,
      visibility: json['visibility'] as String? ?? 'private',
      shareSlug: json['share_slug'] as String?,
      itemsCount: json['items_count'] as int? ?? 0,
      items: (json['items'] as List? ?? [])
          .whereType<Map>()
          .map((item) => WishlistItemModel.fromJson(
                Map<String, dynamic>.from(item),
              ))
          .toList(),
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }
}

class WishlistShareLinkModel extends WishlistShareLink {
  const WishlistShareLinkModel({
    required super.token,
    required super.shareUrl,
    super.expiresAt,
  });

  factory WishlistShareLinkModel.fromJson(Map<String, dynamic> json) {
    return WishlistShareLinkModel(
      token: json['token'] as String,
      shareUrl: json['share_url'] as String? ?? '',
      expiresAt: json['expires_at'] is String
          ? DateTime.parse(json['expires_at'] as String)
          : null,
    );
  }
}

class WishlistOverviewModel extends WishlistOverview {
  const WishlistOverviewModel({
    super.products,
    super.sellers,
    super.posts,
    super.collections,
  });

  factory WishlistOverviewModel.fromJson(Map<String, dynamic> json) {
    return WishlistOverviewModel(
      products: (json['products'] as List? ?? [])
          .whereType<Map>()
          .map((item) {
            final map = Map<String, dynamic>.from(item);
            final product = map['product'] is Map
                ? Map<String, dynamic>.from(map['product'] as Map)
                : map;
            return ProductModel.fromJson(product);
          })
          .toList(),
      sellers: (json['sellers'] as List? ?? [])
          .whereType<Map>()
          .map((item) => SavedSellerModel.fromJson(
                Map<String, dynamic>.from(item),
              ))
          .toList(),
      posts: (json['posts'] as List? ?? [])
          .whereType<Map>()
          .map((item) => SavedPostModel.fromJson(
                Map<String, dynamic>.from(item),
              ))
          .toList(),
      collections: (json['collections'] as List? ?? [])
          .whereType<Map>()
          .map((item) => WishlistCollectionModel.fromJson(
                Map<String, dynamic>.from(item),
              ))
          .toList(),
    );
  }
}
