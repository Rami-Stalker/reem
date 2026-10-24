import 'package:ohara/features/seller_reviews/domain/entities/seller_review.dart';

abstract interface class SellerReviewsRemoteDataSource {
  Future<SellerReviewDesk> desk({bool unansweredOnly});

  /// Writes her public answer. An empty [reply] takes it back down.
  Future<SellerReviewItem> reply(
    String reviewId,
    ReviewTarget target,
    String reply,
  );
}
