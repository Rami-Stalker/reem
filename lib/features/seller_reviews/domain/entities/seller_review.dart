import 'package:equatable/equatable.dart';

/// Which of the two things was reviewed.
///
/// A customer rates a garment and she rates the shop that sent it, and they
/// live in different tables with different ids. The seller does not think in
/// those terms — she thinks about what people are saying — so the desk merges
/// them and carries this tag to know which row a reply belongs to.
enum ReviewTarget {
  product,
  seller;

  static ReviewTarget fromWire(String? value) =>
      (value ?? '').toUpperCase() == 'SELLER'
      ? ReviewTarget.seller
      : ReviewTarget.product;

  String get wire => name.toUpperCase();
}

/// The reviewer, as much of her as a review shows.
class ReviewAuthor extends Equatable {
  const ReviewAuthor({required this.name, this.imageUrl});

  final String name;
  final String? imageUrl;

  @override
  List<Object?> get props => [name, imageUrl];
}

/// One review, with the seller's public answer if she has written one.
class SellerReviewItem extends Equatable {
  const SellerReviewItem({
    required this.id,
    required this.target,
    required this.rating,
    required this.author,
    required this.createdAt,
    this.title,
    this.body,
    this.verifiedPurchase = false,
    this.productTitle,
    this.productImage,
    this.reply,
    this.repliedAt,
  });

  final String id;
  final ReviewTarget target;

  /// One to five.
  final int rating;
  final ReviewAuthor author;
  final String? title;
  final String? body;

  /// Whether the reviewer actually bought it. An unverified complaint and a
  /// verified one are answered differently.
  final bool verifiedPurchase;

  /// Null for a review of the shop itself.
  final String? productTitle;
  final String? productImage;

  final String? reply;
  final DateTime? repliedAt;
  final DateTime createdAt;

  bool get isAnswered => (reply ?? '').trim().isNotEmpty;

  /// Three stars or fewer, unanswered — what an afternoon is best spent on.
  bool get needsAttention => !isAnswered && rating <= 3;

  @override
  List<Object?> get props => [
    id,
    target,
    rating,
    author,
    title,
    body,
    verifiedPurchase,
    productTitle,
    productImage,
    reply,
    repliedAt,
    createdAt,
  ];
}

/// Her whole desk, and how much of it is still waiting on her.
class SellerReviewDesk extends Equatable {
  const SellerReviewDesk({this.reviews = const [], this.unanswered = 0});

  final List<SellerReviewItem> reviews;
  final int unanswered;

  double get averageRating => reviews.isEmpty
      ? 0
      : reviews.fold<int>(0, (sum, review) => sum + review.rating) /
            reviews.length;

  @override
  List<Object?> get props => [reviews, unanswered];
}
