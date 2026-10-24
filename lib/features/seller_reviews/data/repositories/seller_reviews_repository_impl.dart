import 'package:ohara/core/base/repository_handler.dart';
import 'package:ohara/core/result/result.dart';
import 'package:ohara/features/seller_reviews/data/datasources/seller_reviews_remote_datasource.dart';
import 'package:ohara/features/seller_reviews/domain/entities/seller_review.dart';
import 'package:ohara/features/seller_reviews/domain/repositories/seller_reviews_repository.dart';

class SellerReviewsRepositoryImpl
    with RepositoryHandler
    implements SellerReviewsRepository {
  const SellerReviewsRepositoryImpl(this.remote);

  final SellerReviewsRemoteDataSource remote;

  @override
  Future<Result<SellerReviewDesk>> desk({bool unansweredOnly = false}) =>
      guard(() => remote.desk(unansweredOnly: unansweredOnly));

  @override
  Future<Result<SellerReviewItem>> reply(
    String reviewId,
    ReviewTarget target,
    String reply,
  ) => guard(() => remote.reply(reviewId, target, reply));
}
