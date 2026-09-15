// shared/models/post_model.dart

import 'package:reem/core/shared/entities/post.dart';
import 'package:reem/core/shared/entities/product.dart';
import 'package:reem/core/shared/entities/user.dart';
import 'package:reem/core/shared/models/product_model.dart';
import 'package:reem/core/shared/models/user_model.dart';

class PostModel extends Post {
  const PostModel({
    required super.id,
    required super.author,
    super.product,
    required super.caption,
    super.category,
    super.likesCount,
    super.commentsCount,
    super.sharesCount,
    super.savesCount,
    super.isLiked,
    super.isSaved,
    super.isReshared,
    required super.createdAt,
  });

  factory PostModel.fromJson(Map<String, dynamic> json) {
    // A post need not tag anything (Q5) — the API sends `product: null` for a
    // look or an announcement, and casting that to a map used to blow up the
    // whole feed, not just the one post.
    final productJson = json['product'] as Map<String, dynamic>?;
    final product = productJson == null
        ? null
        : ProductModel.fromJson(productJson);
    return PostModel(
      id: json['id'] as String,
      author: UserModel.fromJson(json['author'] as Map<String, dynamic>),
      product: product,
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
      isSaved: json['is_saved'] as bool? ?? false,
      isReshared: json['is_reshared'] as bool? ?? false,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'author': UserModel.fromEntity(author).toJson(),
        'product': product == null
            ? null
            : ProductModel.fromEntity(product!).toJson(),
        'caption': caption,
        'category': category.name,
        'likes_count': likesCount,
        'comments_count': commentsCount,
        'shares_count': sharesCount,
        'saves_count': savesCount,
        'is_liked': isLiked,
        'is_saved': isSaved,
        'is_reshared': isReshared,
        'created_at': createdAt.toIso8601String(),
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
      caption: caption ?? this.caption,
      category: category ?? this.category,
      likesCount: likesCount ?? this.likesCount,
      commentsCount: commentsCount ?? this.commentsCount,
      sharesCount: sharesCount ?? this.sharesCount,
      savesCount: savesCount ?? this.savesCount,
      isLiked: isLiked ?? this.isLiked,
      isSaved: isSaved ?? this.isSaved,
      isReshared: isReshared ?? this.isReshared,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
