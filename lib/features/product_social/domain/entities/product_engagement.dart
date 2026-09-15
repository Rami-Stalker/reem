import 'package:equatable/equatable.dart';

import 'package:reem/core/shared/entities/product.dart';

/// Everything a post card knows about its own engagement, for a product.
///
/// The heart and the bookmark mean what they mean on a post: the **heart** is
/// public applause and has a count; the **bookmark** is her private shelf,
/// which for a product is «المفضّلة». `isPicked` is «أضيفي إلى صفحتي».
class ProductEngagement extends Equatable {
  const ProductEngagement({
    this.likes = 0,
    this.comments = 0,
    this.shares = 0,
    this.picks = 0,
    this.isLiked = false,
    this.isSaved = false,
    this.isPicked = false,
    this.viewerKnown = false,
  });

  /// What a card can say before the batch read answers: the tallies it was
  /// served with, and the favourite flag the catalogue already carries. Whether
  /// she liked or picked it is not known yet, and [viewerKnown] says so.
  factory ProductEngagement.fromProduct(Product product) => ProductEngagement(
    likes: product.likesCount,
    comments: product.commentsCount,
    shares: product.sharesCount,
    picks: product.picksCount,
    isSaved: product.isLiked,
  );

  final int likes;
  final int comments;
  final int shares;
  final int picks;
  final bool isLiked;
  final bool isSaved;
  final bool isPicked;

  /// False until the server has answered for this viewer.
  final bool viewerKnown;

  ProductEngagement copyWith({
    int? likes,
    int? comments,
    int? shares,
    int? picks,
    bool? isLiked,
    bool? isSaved,
    bool? isPicked,
    bool? viewerKnown,
  }) {
    return ProductEngagement(
      likes: likes ?? this.likes,
      comments: comments ?? this.comments,
      shares: shares ?? this.shares,
      picks: picks ?? this.picks,
      isLiked: isLiked ?? this.isLiked,
      isSaved: isSaved ?? this.isSaved,
      isPicked: isPicked ?? this.isPicked,
      viewerKnown: viewerKnown ?? this.viewerKnown,
    );
  }

  @override
  List<Object?> get props => [
    likes,
    comments,
    shares,
    picks,
    isLiked,
    isSaved,
    isPicked,
    viewerKnown,
  ];
}
