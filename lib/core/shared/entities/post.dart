// shared/entities/post.dart

import 'package:equatable/equatable.dart';

import 'package:ohara/core/shared/entities/media.dart';
import 'package:ohara/core/shared/entities/product.dart';
import 'package:ohara/core/shared/entities/user.dart';

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

/// Social content in the feed — usually a product, told as a post.
///
/// [product] is nullable on purpose (Q5): a boutique may post a look, a note
/// or an announcement with nothing to tag. Such a post still has an author, a
/// caption and engagement; it simply has nothing to shop, so surfaces must
/// treat the shoppable half as optional rather than assume it.
class Post extends Equatable {
  final String id;
  final User author;
  final Product? product;
  final String caption;
  final CategoryType category;

  final int likesCount;
  final int commentsCount;
  final int sharesCount;
  final int savesCount;

  final bool isLiked;
  final bool isSaved;

  /// She added it to her own page («أضيفي إلى صفحتي»).
  final bool isReshared;

  final DateTime createdAt;

  const Post({
    required this.id,
    required this.author,
    this.product,
    required this.caption,
    this.category = CategoryType.gifts,
    this.likesCount = 0,
    this.commentsCount = 0,
    this.sharesCount = 0,
    this.savesCount = 0,
    this.isLiked = false,
    this.isSaved = false,
    this.isReshared = false,
    required this.createdAt,
  });

  /// True when there is something to shop behind this post.
  bool get hasProduct => product != null;

  /// A post's media is its product's gallery — exposed directly for
  /// convenience, and empty for a post that tags nothing.
  List<MediaItem> get media => product?.media ?? const [];
  MediaItem? get cover => product?.cover;

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
        isReshared,
        createdAt,
      ];
}
