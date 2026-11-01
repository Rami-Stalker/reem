// shared/models/post_model.dart

import 'package:ohara/core/shared/entities/post.dart';
import 'package:ohara/core/shared/entities/product.dart';
import 'package:ohara/core/shared/entities/reaction_count.dart';
import 'package:ohara/core/shared/entities/user.dart';
import 'package:ohara/core/shared/models/media_model.dart';
import 'package:ohara/core/shared/models/product_model.dart';
import 'package:ohara/core/shared/models/user_model.dart';

class PostModel extends Post {
  const PostModel({
    required super.id,
    required super.author,
    super.product,
    super.products,
    super.photos,
    required super.caption,
    super.category,
    super.likesCount,
    super.commentsCount,
    super.sharesCount,
    super.savesCount,
    super.isLiked,
    super.myReaction,
    super.reactionSummary,
    super.isSaved,
    super.isReshared,
    required super.createdAt,
    super.sponsoredOfferId,
    super.sponsoredStoreTier,
  });

  factory PostModel.fromJson(Map<String, dynamic> json) {
    // A post need not tag anything (Q5) — the API sends `product: null` for a
    // look or an announcement, and casting that to a map used to blow up the
    // whole feed, not just the one post.
    final productJson = json['product'] as Map<String, dynamic>?;
    final product = productJson == null
        ? null
        : ProductModel.fromJson(productJson);
    // A boutique's paid post carries the offer that paid for it.
    final sponsored = json['sponsored'];
    final sponsoredOfferId = sponsored is Map ? sponsored['offer_id'] : null;
    return PostModel(
      id: json['id'] as String,
      author: UserModel.fromJson(json['author'] as Map<String, dynamic>),
      product: product,
      products: [
        for (final item in (json['products'] as List?) ?? const [])
          if (item is Map<String, dynamic>) ProductModel.fromJson(item),
      ],
      photos: [
        for (final item in (json['media'] as List?) ?? const [])
          if (item is Map<String, dynamic>) MediaModel.fromJson(item),
      ].where((m) => m.url.isNotEmpty).toList(),
      caption: json['caption'] as String? ?? '',
      // Derive the display category from the underlying product. The API sends
      // a full category object, not a bare string — read the slug off the
      // parsed entity rather than casting the raw node.
      category: CategoryTypeX.fromString(product?.category.slug),
      likesCount: json['likes_count'] as int? ?? 0,
      commentsCount: json['comments_count'] as int? ?? 0,
      sharesCount: json['shares_count'] as int? ?? 0,
      savesCount: json['saves_count'] as int? ?? 0,
      isLiked: json['is_liked'] as bool? ?? false,
      myReaction: json['my_reaction'] as String?,
      reactionSummary: ReactionCount.listFromJson(json['reaction_summary']),
      isSaved: json['is_saved'] as bool? ?? false,
      isReshared: json['is_reshared'] as bool? ?? false,
      createdAt: DateTime.parse(json['created_at'] as String),
      sponsoredOfferId:
          sponsoredOfferId is String && sponsoredOfferId.isNotEmpty
          ? sponsoredOfferId
          : null,
      sponsoredStoreTier: sponsored is Map
          ? sponsored['store_tier'] as String?
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'author': UserModel.fromEntity(author).toJson(),
    'product': product == null
        ? null
        : ProductModel.fromEntity(product!).toJson(),
    'products': [for (final p in products) ProductModel.fromEntity(p).toJson()],
    'media': [for (final m in photos) MediaModel.fromEntity(m).toJson()],
    'caption': caption,
    'category': category.name,
    'likes_count': likesCount,
    'comments_count': commentsCount,
    'shares_count': sharesCount,
    'saves_count': savesCount,
    'is_liked': isLiked,
    'my_reaction': myReaction,
    'reaction_summary': ReactionCount.listToJson(reactionSummary),
    'is_saved': isSaved,
    'is_reshared': isReshared,
    'created_at': createdAt.toIso8601String(),
    if (sponsoredOfferId != null)
      'sponsored': {
        'offer_id': sponsoredOfferId,
        'placement': 'feed_top',
        'store_tier': sponsoredStoreTier,
      },
  };

  PostModel copyWith({
    String? id,
    User? author,
    Product? product,
    String? caption,
    CategoryType? category,
    int? likesCount,
    int? commentsCount,
    int? sharesCount,
    int? savesCount,
    bool? isLiked,
    bool? isSaved,
    bool? isReshared,
    DateTime? createdAt,
  }) {
    return PostModel(
      id: id ?? this.id,
      author: author ?? this.author,
      product: product ?? this.product,
      products: products,
      photos: photos,
      caption: caption ?? this.caption,
      category: category ?? this.category,
      likesCount: likesCount ?? this.likesCount,
      commentsCount: commentsCount ?? this.commentsCount,
      sharesCount: sharesCount ?? this.sharesCount,
      savesCount: savesCount ?? this.savesCount,
      isLiked: isLiked ?? this.isLiked,
      myReaction: myReaction,
      reactionSummary: reactionSummary,
      isSaved: isSaved ?? this.isSaved,
      isReshared: isReshared ?? this.isReshared,
      createdAt: createdAt ?? this.createdAt,
      sponsoredOfferId: sponsoredOfferId,
      sponsoredStoreTier: sponsoredStoreTier,
    );
  }
}
