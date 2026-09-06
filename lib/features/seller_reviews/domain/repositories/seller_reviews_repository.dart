import 'package:reem/core/result/result.dart';
import 'package:reem/features/seller_reviews/domain/entities/seller_review.dart';

abstract interface class SellerReviewsRepository {
  Future<Result<SellerReviewDesk>> desk({bool unansweredOnly});

  Future<Result<SellerReviewItem>> reply(
    String reviewId,
    ReviewTarget target,
    String reply,
  );
}
