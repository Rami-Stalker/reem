import 'package:reem/core/result/result.dart';

import 'package:reem/features/reputation/domain/entities/reputation_entities.dart';

abstract interface class ReputationRepository {
  Future<Result<List<ReviewEntity>>> getProductReviews(String productId);

  Future<Result<ReviewEntity>> submitProductReview({
    required String productId,
    required int rating,
    String? title,
    String? body,
    String? orderId,
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
