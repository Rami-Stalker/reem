// shared/entities/post.dart

import 'package:equatable/equatable.dart';

import 'media.dart';
import 'product.dart';
import 'user.dart';

/// High-level merchandising category, used for feed filtering and iconography.
enum CategoryType {
  clothing,
  makeup,
  perfumes,
  bags,
  flowers,
  shoes,
  chocolate,
  bathBody,
  gifts,
}

extension CategoryTypeX on CategoryType {
  String get label => switch (this) {
        CategoryType.clothing => 'Clothing',
        CategoryType.makeup => 'Makeup',
        CategoryType.perfumes => 'Perfumes',
        CategoryType.bags => 'Bags',
        CategoryType.flowers => 'Flowers',
        CategoryType.shoes => 'Shoes',
        CategoryType.chocolate => 'Chocolate',
        CategoryType.bathBody => 'Bath & Body',
        CategoryType.gifts => 'Gifts',
      };

  /// Maps a free-form product category string onto a display category.
  static CategoryType fromString(String? value) {
    switch ((value ?? '').toLowerCase()) {
      case 'clothing':
      case 'dresses':
      case 'skirts':
      case 'knitwear':
      case 'tops':
        return CategoryType.clothing;
      case 'makeup':
      case 'cosmetics':
        return CategoryType.makeup;
      case 'perfume':
      case 'perfumes':
      case 'fragrance':
        return CategoryType.perfumes;
      case 'bags':
      case 'handbags':
        return CategoryType.bags;
      case 'flowers':
        return CategoryType.flowers;
      case 'shoes':
      case 'heels':
        return CategoryType.shoes;
      case 'chocolate':
      case 'sweets':
        return CategoryType.chocolate;
      case 'bath':
      case 'bathbody':
      case 'bath_body':
        return CategoryType.bathBody;
      default:
        return CategoryType.gifts;
    }
  }
}

/// A product showcased as social content in the feed.
class Post extends Equatable {
  final String id;
  final User author;
  final Product product;
  final String caption;
  final CategoryType category;

  final int likesCount;
  final int commentsCount;
  final int sharesCount;
  final int savesCount;

  final bool isLiked;
  final bool isSaved;

  final DateTime createdAt;

  const Post({
    required this.id,
    required this.author,
    required this.product,
    required this.caption,
    this.category = CategoryType.gifts,
    this.likesCount = 0,
    this.commentsCount = 0,
    this.sharesCount = 0,
    this.savesCount = 0,
    this.isLiked = false,
    this.isSaved = false,
    required this.createdAt,
  });

  /// A post's media is its product's gallery — exposed directly for convenience.
  List<MediaItem> get media => product.media;
  MediaItem? get cover => product.cover;

  @override
  List<Object?> get props => [
        id,
        author,
        product,
        caption,
        category,
        likesCount,
        commentsCount,
        sharesCount,
        savesCount,
        isLiked,
        isSaved,
        createdAt,
      ];
}
