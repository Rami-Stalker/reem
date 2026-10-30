import 'package:ohara/core/base/repository_handler.dart';
import 'package:ohara/core/result/result.dart';
import 'package:ohara/features/reputation/data/datasources/reputation_remote_datasource.dart';
import 'package:ohara/features/reputation/domain/entities/fit_entities.dart';
import 'package:ohara/features/reputation/domain/entities/reputation_entities.dart';
import 'package:ohara/features/reputation/domain/repositories/reputation_repository.dart';

class ReputationRepositoryImpl
    with RepositoryHandler
    implements ReputationRepository {
  const ReputationRepositoryImpl({required this.remote});

  final ReputationRemoteDataSource remote;

  @override
  Future<Result<List<ReviewEntity>>> getProductReviews(
    String productId, {
    ReviewFilter filter = ReviewFilter.all,
  }) => guard(() => remote.getProductReviews(productId, filter: filter));

  @override
  Future<Result<ReviewEntity>> submitProductReview({
    required String productId,
    required int rating,
    String? title,
    String? body,
    String? orderId,
    ReviewFitInput? fit,
  }) {
    return guard(
      () => remote.submitProductReview(
        productId: productId,
        rating: rating,
        title: title,
        body: body,
        orderId: orderId,
        fit: fit == null
            ? null
            : ReviewFitDraft(
                fit: fit.fit,
                photoUrls: fit.photoUrls,
                shareFit: fit.shareFit,
              ),
      ),
    );
  }

  @override
  Future<Result<ReviewEligibility>> getProductReviewEligibility(
    String productId,
  ) => guard(
    () => remote.getProductReviewEligibility(productId),
    operation: 'review eligibility',
  );

  @override
  Future<Result<ProductFit>> getProductFit(String productId) =>
      guard(() => remote.getProductFit(productId), operation: 'product fit');

  @override
  Future<Result<FitProfile>> getFitProfile() =>
      guard(remote.getFitProfile, operation: 'fit profile');

  @override
  Future<Result<FitProfile>> saveFitProfile({
    int? heightCm,
    String? usualSize,
    bool shareOnReviews = true,
  }) => guard(
    () => remote.saveFitProfile(
      FitProfileDraft(
        heightCm: heightCm,
        usualSize: usualSize,
        shareOnReviews: shareOnReviews,
      ),
    ),
    operation: 'save fit profile',
  );

  @override
  Future<Result<MyReviews>> getMyReviews() => guard(remote.getMyReviews);

  @override
  Future<Result<List<ReviewEntity>>> getSellerReviews(String sellerId) =>
      guard(() => remote.getSellerReviews(sellerId));

  @override
  Future<Result<ReviewEntity>> submitSellerReview({
    required String sellerId,
    required int rating,
    String? title,
    String? body,
    String? orderId,
  }) {
    return guard(
      () => remote.submitSellerReview(
        sellerId: sellerId,
        rating: rating,
        title: title,
        body: body,
        orderId: orderId,
      ),
    );
  }

  @override
  Future<Result<SellerReputationSummary>> getSellerReputation(
    String sellerId,
  ) => guard(() => remote.getSellerReputation(sellerId));

  @override
  Future<Result<void>> requestTrustedSellerVerification({Object? evidence}) =>
      guard(() => remote.requestTrustedSellerVerification(evidence: evidence));
}
