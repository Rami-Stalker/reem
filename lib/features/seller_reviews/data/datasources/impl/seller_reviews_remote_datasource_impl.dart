import 'package:ohara/core/network/api_endpoints.dart';
import 'package:ohara/core/network/base_remote_datasource.dart';
import 'package:ohara/features/seller_reviews/data/datasources/seller_reviews_remote_datasource.dart';
import 'package:ohara/features/seller_reviews/data/models/seller_review_model.dart';
import 'package:ohara/features/seller_reviews/domain/entities/seller_review.dart';

final class SellerReviewsRemoteDataSourceImpl extends BaseRemoteDataSource
    implements SellerReviewsRemoteDataSource {
  const SellerReviewsRemoteDataSourceImpl(super.dio);

  @override
  Future<SellerReviewDesk> desk({bool unansweredOnly = false}) async =>
      SellerReviewMapper.deskFromJson(
        await getJson(
          ApiEndpoints.sellerReviewDesk,
          query: {if (unansweredOnly) 'filter': 'unanswered'},
        ),
      );

  @override
  Future<SellerReviewItem> reply(
    String reviewId,
    ReviewTarget target,
    String reply,
  ) async => SellerReviewMapper.fromJson({
    // The reply route answers with the review alone; the desk's own fields —
    // which product it was about — are not on it, so the caller merges.
    ...await postJson(
      ApiEndpoints.sellerReviewReply(reviewId),
      body: {'target_type': target.wire, 'reply': reply},
    ),
    'target_type': target.wire,
  });
}
