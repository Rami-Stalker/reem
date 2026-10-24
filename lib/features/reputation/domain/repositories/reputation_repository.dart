import 'package:ohara/core/result/result.dart';

import 'package:ohara/features/reputation/domain/entities/fit_entities.dart';
import 'package:ohara/features/reputation/domain/entities/reputation_entities.dart';

/// The fit half of a product review, in domain terms.
class ReviewFitInput {
  const ReviewFitInput({this.fit, this.photoUrls = const [], this.shareFit});

  final ReviewFit? fit;
  final List<String> photoUrls;
  final bool? shareFit;
}

abstract interface class ReputationRepository {
  Future<Result<List<ReviewEntity>>> getProductReviews(
    String productId, {
    ReviewFilter filter = ReviewFilter.all,
  });

  Future<Result<ReviewEntity>> submitProductReview({
    required String productId,
    required int rating,
    String? title,
    String? body,
    String? orderId,
    ReviewFitInput? fit,
  });

  /// «تقييمات من بمقاسي» — how the piece fits, overall and for women like her.
  Future<Result<ProductFit>> getProductFit(String productId);

  /// «مقاساتي».
  Future<Result<FitProfile>> getFitProfile();

  Future<Result<FitProfile>> saveFitProfile({
    int? heightCm,
    String? usualSize,
    bool shareOnReviews = true,
  });

  /// Everything she has written, newest first, with the two figures her
  /// profile already displayed.
  Future<Result<MyReviews>> getMyReviews();

  Future<Result<List<ReviewEntity>>> getSellerReviews(String sellerId);

  Future<Result<ReviewEntity>> submitSellerReview({
    required String sellerId,
    required int rating,
    String? title,
    String? body,
    String? orderId,
  });

  Future<Result<SellerReputationSummary>> getSellerReputation(String sellerId);

  Future<Result<void>> requestTrustedSellerVerification({Object? evidence});
}
