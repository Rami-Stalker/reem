import 'package:equatable/equatable.dart';
import 'package:ohara/core/shared/entities/user.dart';
import 'package:ohara/features/reputation/domain/entities/fit_entities.dart';

class ReviewEntity extends Equatable {
  const ReviewEntity({
    required this.id,
    required this.user,
    required this.rating,
    this.title,
    this.body,
    this.verifiedPurchase = false,
    this.status = 'pending',
    this.helpfulCount = 0,
    required this.createdAt,
    this.fit,
    this.sizeBought,
    this.photos = const [],
  });

  final String id;
  final User user;
  final int rating;
  final String? title;
  final String? body;
  final bool verifiedPurchase;
  final String status;
  final int helpfulCount;
  final DateTime createdAt;

  // ── «تقييمات من بمقاسي» ────────────────────────────────────────────────

  /// How it fit her, when she said.
  final ReviewFit? fit;

  /// The size that shipped, read by the server from her delivered order.
  final String? sizeBought;

  /// Up to four photographs of the piece.
  ///
  /// Note what is *not* here: the reviewer's height and usual size. The
  /// server stores them to match reviews to women her size and never sends
  /// them — a named woman's body has no place under her review.
  final List<String> photos;

  /// Whether the card has anything to say about fit at all.
  bool get hasFitFacts => fit != null || sizeBought != null;

  @override
  List<Object?> get props => [
        id,
        user,
        rating,
        title,
        body,
        verifiedPurchase,
        status,
        helpfulCount,
        createdAt,
    fit,
    sizeBought,
    photos,
      ];
}

class SellerBadgeEntity extends Equatable {
  const SellerBadgeEntity({
    required this.id,
    required this.type,
    required this.label,
    this.reason,
    required this.awardedAt,
    this.expiresAt,
  });

  final String id;
  final String type;
  final String label;
  final String? reason;
  final DateTime awardedAt;
  final DateTime? expiresAt;

  @override
  List<Object?> get props => [id, type, label, reason, awardedAt, expiresAt];
}

class SellerReputationEntity extends Equatable {
  const SellerReputationEntity({
    this.averageRating = 0,
    this.reviewsCount = 0,
    this.verifiedReviewsCount = 0,
    this.performanceScore = 0,
    this.customerSatisfactionScore = 0,
    this.responseScore,
    this.fulfillmentScore = 0,
    this.topSellerTier = 'standard',
    this.trustedStatus = 'pending',
  });

  final double averageRating;
  final int reviewsCount;
  final int verifiedReviewsCount;
  final double performanceScore;
  final double customerSatisfactionScore;
  /// Null when she has never been messaged — see the backend column, which
  /// is nullable for the same reason.
  final double? responseScore;
  final double fulfillmentScore;
  final String topSellerTier;
  final String trustedStatus;

  @override
  List<Object?> get props => [
        averageRating,
        reviewsCount,
        verifiedReviewsCount,
        performanceScore,
        customerSatisfactionScore,
        responseScore,
        fulfillmentScore,
        topSellerTier,
        trustedStatus,
      ];
}

class SellerReputationSummary extends Equatable {
  const SellerReputationSummary({
    required this.seller,
    required this.reputation,
    this.badges = const [],
  });

  final User seller;
  final SellerReputationEntity reputation;
  final List<SellerBadgeEntity> badges;

  bool get isTrusted => reputation.trustedStatus == 'verified';

  @override
  List<Object?> get props => [seller, reputation, badges];
}

/// What a review was written *about*. A product review carries the piece; a
/// shop review carries the boutique.
class ReviewSubject extends Equatable {
  const ReviewSubject({required this.id, required this.title, this.imageUrl});

  final String id;
  final String title;
  final String? imageUrl;

  @override
  List<Object?> get props => [id, title, imageUrl];
}

/// One review she wrote, with the thing she wrote it about attached.
///
/// Separate from [ReviewEntity] — which carries the *author* because it is read
/// by people looking at a product — since here the author is always her and the
/// interesting half is the subject.
class AuthoredReview extends Equatable {
  const AuthoredReview({
    required this.id,
    required this.rating,
    required this.isAboutProduct,
    required this.subject,
    required this.createdAt,
    this.title,
    this.body,
    this.status = 'pending',
    this.sellerReply,
    this.verifiedPurchase = false,
  });

  final String id;
  final int rating;

  /// False means it is a review of a boutique rather than a piece.
  final bool isAboutProduct;
  final ReviewSubject subject;
  final DateTime createdAt;
  final String? title;
  final String? body;

  /// Her own pending reviews are returned too, so this is worth showing: a
  /// review being moderated has not been lost.
  final String status;
  final String? sellerReply;
  final bool verifiedPurchase;

  bool get isPending => status == 'pending';
  bool get isRejected => status == 'rejected';
  bool get hasReply => (sellerReply ?? '').trim().isNotEmpty;

  @override
  List<Object?> get props => [
        id,
        rating,
        isAboutProduct,
        subject,
        createdAt,
        title,
        body,
        status,
        sellerReply,
        verifiedPurchase,
      ];
}

/// Her reviews plus the two figures the profile already displayed.
class MyReviews extends Equatable {
  const MyReviews({this.reviews = const [], this.count = 0, this.average = 0});

  final List<AuthoredReview> reviews;
  final int count;
  final double average;

  bool get isEmpty => reviews.isEmpty;

  @override
  List<Object?> get props => [reviews, count, average];
}
