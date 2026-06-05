// shared/models/post_model.dart

import '../entities/post.dart';

import 'product_model.dart';
import 'user_model.dart';

class PostModel extends Post {
  const PostModel({
    required super.id,
    required super.author,
    required super.product,
    required super.caption,
    required super.category,
    required super.likesCount,
    required super.commentsCount,
    required super.sharesCount,
    required super.isLiked,
    required super.createdAt,
  });

  factory PostModel.fromJson(Map<String, dynamic> json) {
    return PostModel(
      id: json['id'],

      author: UserModel.fromJson(json['author']),

      product: ProductModel.fromJson(json['product']),

      caption: json['caption'],

      category: _mapType(json['type']),

      likesCount: json['likes_count'] ?? 0,
      commentsCount: json['comments_count'] ?? 0,
      sharesCount: json['shares_count'] ?? 0,

      isLiked: json['is_liked'] ?? false,

      createdAt: DateTime.parse(json['created_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,

      'author': (author as UserModel).toJson(),

      'product': (product as ProductModel).toJson(),

      'caption': caption,

      'category': category.name,

      'likes_count': likesCount,
      'comments_count': commentsCount,
      'shares_count': sharesCount,

      'is_liked': isLiked,

      'created_at': createdAt.toIso8601String(),
    };
  }

    static CategoryType _mapType(String type) {
    switch (type) {
      case 'clothing':
        return CategoryType.clothing;

      case 'makeup':
        return CategoryType.makeup;

      case 'perfumes':
        return CategoryType.perfumes;

      case 'flowers':
        return CategoryType.flowers;

      case 'shoes':
        return CategoryType.shoes;

      case 'chocolate':
        return CategoryType.chocolate;

      case 'bathBody':
        return CategoryType.bathBody;

      default:
        return CategoryType.gifts;
    }
  }
}