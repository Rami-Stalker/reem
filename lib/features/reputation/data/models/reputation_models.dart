import 'package:ohara/core/shared/models/user_model.dart';

import 'package:ohara/features/reputation/domain/entities/fit_entities.dart';
import 'package:ohara/features/reputation/domain/entities/reputation_entities.dart';

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
    super.fit,
    super.sizeBought,
    super.photos,
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
      // «تقييمات من بمقاسي». Absent on a shop review and on every review
      // written before them, which is the same as "she did not say".
      fit: ReviewFit.fromWire(json['fit']),
      sizeBought: _text(json['size_bought']),
      photos: json['photos'] is List
          ? (json['photos'] as List).whereType<String>().toList()
          : const [],
    );
  }
}

ReviewEligibility reviewEligibilityFromJson(Map<String, dynamic> json) {
  final review = json['review'];
  return ReviewEligibility(
    canReview: json['can_review'] == true,
    block: ReviewBlock.fromWire(json['reason']),
    myReview: review is Map
        ? ReviewModel.fromJson(Map<String, dynamic>.from(review))
        : null,
  );
}

String? _text(Object? value) {
  final text = value is String ? value.trim() : null;
  return text == null || text.isEmpty ? null : text;
}

FitTally fitTallyFromJson(Object? value) {
  final json = value is Map
      ? Map<String, dynamic>.from(value)
      : const <String, dynamic>{};
  int count(String key) => (json[key] as num?)?.toInt() ?? 0;
  return FitTally(
    runsSmall: count('runs_small'),
    trueToSize: count('true_to_size'),
    runsLarge: count('runs_large'),
    total: count('total'),
    enough: json['enough'] == true,
    verdict: ReviewFit.fromWire(json['verdict']),
  );
}

ProductFit productFitFromJson(Map<String, dynamic> json) {
  final near = json['near_me'];
  return ProductFit(
    overall: fitTallyFromJson(json['overall']),
    hasProfile: json['has_profile'] == true,
    nearMe: near is Map ? fitTallyFromJson(near) : null,
    nearMeReviews: near is Map
        ? ((near['reviews_count'] as num?)?.toInt() ?? 0)
        : 0,
    suggestedSize: _text(json['suggested_size']),
    photosCount: (json['photos_count'] as num?)?.toInt() ?? 0,
  );
}

FitProfile fitProfileFromJson(Map<String, dynamic> json) => FitProfile(
  heightCm: (json['height_cm'] as num?)?.toInt(),
  usualSize: _text(json['usual_size']),
  shareOnReviews: json['share_on_reviews'] != false,
  sizes: json['sizes'] is List
      ? (json['sizes'] as List).whereType<String>().toList()
      : const [],
);

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
      // Not `?? 0`: an unmeasured reply time is not a reply time of zero.
      responseScore: (json['response_score'] as num?)?.toDouble(),
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
      seller: UserModel.fromJson(
        Map<String, dynamic>.from(json['seller'] as Map),
      ),
      reputation: SellerReputationModel.fromJson(
        Map<String, dynamic>.from(json['reputation'] as Map),
      ),
      badges: (json['badges'] as List? ?? [])
          .whereType<Map>()
          .map(
            (item) =>
                SellerBadgeModel.fromJson(Map<String, dynamic>.from(item)),
          )
          .toList(),
    );
  }
}

class AuthoredReviewModel extends AuthoredReview {
  const AuthoredReviewModel({
    required super.id,
    required super.rating,
    required super.isAboutProduct,
    required super.subject,
    required super.createdAt,
    super.title,
    super.body,
    super.status,
    super.sellerReply,
    super.verifiedPurchase,
  });

  factory AuthoredReviewModel.fromJson(Map<String, dynamic> json) {
    final subject = json['subject'];
    return AuthoredReviewModel(
      id: json['id'] as String,
      rating: (json['rating'] as num?)?.toInt() ?? 0,
      isAboutProduct:
          (json['target_type'] as String?)?.toUpperCase() != 'SELLER',
      subject: ReviewSubject(
        id: subject is Map ? subject['id'] as String? ?? '' : '',
        title: subject is Map ? subject['title'] as String? ?? '' : '',
        imageUrl: subject is Map ? subject['image'] as String? : null,
      ),
      createdAt: DateTime.parse(json['created_at'] as String).toLocal(),
      title: json['title'] as String?,
      body: json['body'] as String?,
      status: json['status'] as String? ?? 'pending',
      sellerReply: json['seller_reply'] as String?,
      verifiedPurchase: json['verified_purchase'] as bool? ?? false,
    );
  }
}

class MyReviewsModel extends MyReviews {
  const MyReviewsModel({super.reviews, super.count, super.average});

  factory MyReviewsModel.fromJson(Map<String, dynamic> json) {
    final data = json['data'];
    return MyReviewsModel(
      reviews: data is List
          ? data
              .whereType<Map>()
                .map(
                  (e) => AuthoredReviewModel.fromJson(
                    Map<String, dynamic>.from(e),
                  ),
                )
              .toList()
          : const [],
      count: (json['count'] as num?)?.toInt() ?? 0,
      average: (json['average'] as num?)?.toDouble() ?? 0,
    );
  }
}
