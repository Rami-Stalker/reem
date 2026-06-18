import 'package:reem/core/shared/models/user_model.dart';

import '../../domain/entities/reputation_entities.dart';

class ReviewModel extends ReviewEntity {
  const ReviewModel({
    required super.id,
    required super.user,
    required super.rating,
    super.title,
    super.body,
    super.verifiedPurchase,
    super.status,
    super.helpfulCount,
    required super.createdAt,
  });

  factory ReviewModel.fromJson(Map<String, dynamic> json) {
    return ReviewModel(
      id: json['id'] as String,
      user: UserModel.fromJson(Map<String, dynamic>.from(json['user'] as Map)),
      rating: json['rating'] as int? ?? 0,
      title: json['title'] as String?,
      body: json['body'] as String?,
      verifiedPurchase: json['verified_purchase'] as bool? ?? false,
      status: json['status'] as String? ?? 'pending',
      helpfulCount: json['helpful_count'] as int? ?? 0,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}

class SellerBadgeModel extends SellerBadgeEntity {
  const SellerBadgeModel({
    required super.id,
    required super.type,
    required super.label,
    super.reason,
    required super.awardedAt,
    super.expiresAt,
  });

  factory SellerBadgeModel.fromJson(Map<String, dynamic> json) {
    return SellerBadgeModel(
      id: json['id'] as String,
      type: json['type'] as String? ?? 'trusted',
      label: json['label'] as String? ?? 'Trusted seller',
      reason: json['reason'] as String?,
      awardedAt: DateTime.parse(json['awarded_at'] as String),
      expiresAt: json['expires_at'] is String
          ? DateTime.parse(json['expires_at'] as String)
          : null,
    );
  }
}

class SellerReputationModel extends SellerReputationEntity {
  const SellerReputationModel({
    super.averageRating,
    super.reviewsCount,
    super.verifiedReviewsCount,
    super.performanceScore,
    super.customerSatisfactionScore,
    super.responseScore,
    super.fulfillmentScore,
    super.topSellerTier,
    super.trustedStatus,
  });

  factory SellerReputationModel.fromJson(Map<String, dynamic> json) {
    return SellerReputationModel(
      averageRating: (json['average_rating'] as num?)?.toDouble() ?? 0,
      reviewsCount: json['reviews_count'] as int? ?? 0,
      verifiedReviewsCount: json['verified_reviews_count'] as int? ?? 0,
      performanceScore: (json['performance_score'] as num?)?.toDouble() ?? 0,
      customerSatisfactionScore:
          (json['customer_satisfaction_score'] as num?)?.toDouble() ?? 0,
      responseScore: (json['response_score'] as num?)?.toDouble() ?? 0,
      fulfillmentScore: (json['fulfillment_score'] as num?)?.toDouble() ?? 0,
      topSellerTier: json['top_seller_tier'] as String? ?? 'standard',
      trustedStatus: json['trusted_status'] as String? ?? 'pending',
    );
  }
}

class SellerReputationSummaryModel extends SellerReputationSummary {
  const SellerReputationSummaryModel({
    required super.seller,
    required super.reputation,
    super.badges,
  });

  factory SellerReputationSummaryModel.fromJson(Map<String, dynamic> json) {
    return SellerReputationSummaryModel(
      seller: UserModel.fromJson(Map<String, dynamic>.from(json['seller'] as Map)),
      reputation: SellerReputationModel.fromJson(
        Map<String, dynamic>.from(json['reputation'] as Map),
      ),
      badges: (json['badges'] as List? ?? [])
          .whereType<Map>()
          .map((item) => SellerBadgeModel.fromJson(
                Map<String, dynamic>.from(item),
              ))
          .toList(),
    );
  }
}
