import 'package:equatable/equatable.dart';
import 'package:ohara/core/shared/entities/post.dart';
import 'package:ohara/core/shared/entities/product.dart';
import 'package:ohara/core/shared/entities/user.dart';

class SavedSeller extends Equatable {
  const SavedSeller({required this.seller, required this.savedAt});

  final User seller;
  final DateTime savedAt;

  @override
  List<Object?> get props => [seller, savedAt];
}

class SavedPost extends Equatable {
  const SavedPost({required this.post, required this.savedAt});

  final Post post;
  final DateTime savedAt;

  @override
  List<Object?> get props => [post, savedAt];
}

class WishlistItem extends Equatable {
  const WishlistItem({
    required this.id,
    required this.type,
    this.product,
    this.seller,
    this.post,
    this.priceWhenSaved,
    this.notifyPriceDrop = true,
    this.notifyBackInStock = true,
    this.note,
    required this.createdAt,
  });

  final String id;
  final String type;
  final Product? product;
  final User? seller;
  final Post? post;
  final double? priceWhenSaved;
  final bool notifyPriceDrop;
  final bool notifyBackInStock;
  final String? note;
  final DateTime createdAt;

  String get title => switch (type) {
        'product' => product?.title ?? 'Saved product',
        'seller' => seller?.name ?? 'Saved seller',
        'post' => post?.caption.isNotEmpty == true ? post!.caption : 'Saved post',
        _ => 'Saved item',
      };

  @override
  List<Object?> get props => [
        id,
        type,
        product,
        seller,
        post,
        priceWhenSaved,
        notifyPriceDrop,
        notifyBackInStock,
        note,
        createdAt,
      ];
}

class WishlistCollection extends Equatable {
  const WishlistCollection({
    required this.id,
    required this.name,
    this.description,
    required this.visibility,
    this.shareSlug,
    this.itemsCount = 0,
    this.items = const [],
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String name;
  final String? description;
  final String visibility;
  final String? shareSlug;
  final int itemsCount;
  final List<WishlistItem> items;
  final DateTime createdAt;
  final DateTime updatedAt;

  @override
  List<Object?> get props => [
        id,
        name,
        description,
        visibility,
        shareSlug,
        itemsCount,
        items,
        createdAt,
        updatedAt,
      ];
}

class WishlistShareLink extends Equatable {
  const WishlistShareLink({
    required this.token,
    required this.shareUrl,
    this.expiresAt,
  });

  final String token;
  final String shareUrl;
  final DateTime? expiresAt;

  @override
  List<Object?> get props => [token, shareUrl, expiresAt];
}

class WishlistOverview extends Equatable {
  const WishlistOverview({
    this.products = const [],
    this.sellers = const [],
    this.posts = const [],
    this.collections = const [],
  });

  final List<Product> products;
  final List<SavedSeller> sellers;
  final List<SavedPost> posts;
  final List<WishlistCollection> collections;

  bool get isEmpty =>
      products.isEmpty &&
      sellers.isEmpty &&
      posts.isEmpty &&
      collections.isEmpty;

  int get totalSaved =>
      products.length +
      sellers.length +
      posts.length +
      collections.fold<int>(0, (sum, collection) => sum + collection.itemsCount);

  @override
  List<Object?> get props => [products, sellers, posts, collections];
}
