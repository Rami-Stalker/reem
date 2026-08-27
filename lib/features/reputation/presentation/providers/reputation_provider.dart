import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:reem/core/presentation/providers/core_providers.dart';
import 'package:reem/core/result/result.dart';

import 'package:reem/features/reputation/data/datasources/impl/reputation_remote_datasource_impl.dart';
import 'package:reem/features/reputation/data/datasources/reputation_remote_datasource.dart';
import 'package:reem/features/reputation/data/repositories/reputation_repository_impl.dart';
import 'package:reem/features/reputation/domain/entities/reputation_entities.dart';
import 'package:reem/features/reputation/domain/repositories/reputation_repository.dart';

final reputationRemoteDataSourceProvider = Provider<ReputationRemoteDataSource>(
  (ref) => ReputationRemoteDataSourceImpl(ref.watch(dioProvider)),
);

final reputationRepositoryProvider = Provider<ReputationRepository>(
  (ref) => ReputationRepositoryImpl(
    remote: ref.watch(reputationRemoteDataSourceProvider),
  ),
);

final productReviewsProvider =
    FutureProvider.family<List<ReviewEntity>, String>((ref, productId) async {
  final result =
      await ref.watch(reputationRepositoryProvider).getProductReviews(productId);
  return result.fold((failure) => throw failure.message, (reviews) => reviews);
});

final sellerReviewsProvider =
    FutureProvider.family<List<ReviewEntity>, String>((ref, sellerId) async {
  final result =
      await ref.watch(reputationRepositoryProvider).getSellerReviews(sellerId);
  return result.fold((failure) => throw failure.message, (reviews) => reviews);
});

final sellerReputationProvider =
    FutureProvider.family<SellerReputationSummary, String>((ref, sellerId) async {
  final result =
      await ref.watch(reputationRepositoryProvider).getSellerReputation(sellerId);
  return result.fold((failure) => throw failure.message, (summary) => summary);
});

final reputationActionsProvider = Provider<ReputationActions>(
  (ref) => ReputationActions(ref.watch(reputationRepositoryProvider)),
);

class ReputationActions {
  const ReputationActions(this.repository);

  final ReputationRepository repository;

  Future<Result<ReviewEntity>> submitProductReview({
    required String productId,
    required int rating,
    String? title,
    String? body,
    String? orderId,
  }) {
    return repository.submitProductReview(
      productId: productId,
      rating: rating,
      title: title,
      body: body,
      orderId: orderId,
    );
  }

  Future<Result<ReviewEntity>> submitSellerReview({
    required String sellerId,
    required int rating,
    String? title,
    String? body,
    String? orderId,
  }) {
    return repository.submitSellerReview(
      sellerId: sellerId,
      rating: rating,
      title: title,
      body: body,
      orderId: orderId,
    );
  }

  Future<Result<void>> requestTrustedSellerVerification({Object? evidence}) {
    return repository.requestTrustedSellerVerification(evidence: evidence);
  }
}
