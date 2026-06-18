import 'package:equatable/equatable.dart';
import 'package:reem/core/shared/entities/user.dart';

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
    this.responseScore = 0,
    this.fulfillmentScore = 0,
    this.topSellerTier = 'standard',
    this.trustedStatus = 'pending',
  });

  final double averageRating;
  final int reviewsCount;
  final int verifiedReviewsCount;
  final double performanceScore;
  final double customerSatisfactionScore;
  final double responseScore;
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
