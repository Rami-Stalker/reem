// shared/entities/post.dart

import 'package:equatable/equatable.dart';

import 'product.dart';
import 'user.dart';

class Post extends Equatable {
  final String id;

  final User author;

  final Product product;

  final String caption;

  final int likesCount;
  final int commentsCount;
  final int sharesCount;

  final bool isLiked;

  final DateTime createdAt;

  const Post({
    required this.id,
    required this.author,
    required this.product,
    required this.caption,
    required this.likesCount,
    required this.commentsCount,
    required this.sharesCount,
    required this.isLiked,
    required this.createdAt,
  });

  @override
  List<Object?> get props => [
        id,
        author,
        product,
        caption,
        likesCount,
        commentsCount,
        sharesCount,
        isLiked,
        createdAt,
      ];
}