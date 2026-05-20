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

      'likes_count': likesCount,
      'comments_count': commentsCount,
      'shares_count': sharesCount,

      'is_liked': isLiked,

      'created_at': createdAt.toIso8601String(),
    };
  }
}