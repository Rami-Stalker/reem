import 'package:reem/features/reputation/data/models/reputation_models.dart';

abstract interface class ReputationRemoteDataSource {
  Future<List<ReviewModel>> getProductReviews(String productId);

  Future<ReviewModel> submitProductReview({
    required String productId,
    required int rating,
    String? title,
    String? body,
    String? orderId,
  });

  Future<MyReviewsModel> getMyReviews();

  Future<List<ReviewModel>> getSellerReviews(String sellerId);

  Future<ReviewModel> submitSellerReview({
    required String sellerId,
    required int rating,
    String? title,
    String? body,
    String? orderId,
  });

  Future<SellerReputationSummaryModel> getSellerReputation(String sellerId);

  Future<void> requestTrustedSellerVerification({Object? evidence});
}
