import 'package:reem/core/base/repository_handler.dart';
import 'package:reem/core/result/result.dart';

import '../../domain/entities/reputation_entities.dart';
import '../../domain/repositories/reputation_repository.dart';
import '../datasources/reputation_remote_datasource.dart';

class ReputationRepositoryImpl
    with RepositoryHandler
    implements ReputationRepository {
  const ReputationRepositoryImpl({required this.remote});

  final ReputationRemoteDataSource remote;

  @override
  Future<Result<List<ReviewEntity>>> getProductReviews(String productId) =>
      guard(() => remote.getProductReviews(productId));

  @override
  Future<Result<ReviewEntity>> submitProductReview({
    required String productId,
    required int rating,
    String? title,
    String? body,
    String? orderId,
  }) {
    return guard(
      () => remote.submitProductReview(
        productId: productId,
        rating: rating,
        title: title,
        body: body,
        orderId: orderId,
      ),
    );
  }

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
  Future<Result<SellerReputationSummary>> getSellerReputation(String sellerId) =>
      guard(() => remote.getSellerReputation(sellerId));

  @override
  Future<Result<void>> requestTrustedSellerVerification({Object? evidence}) =>
      guard(() => remote.requestTrustedSellerVerification(evidence: evidence));
}
