import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:reem/core/presentation/providers/core_providers.dart';
import 'package:reem/core/result/result.dart';
import 'package:reem/features/auth/presentation/providers/auth_provider.dart';

import 'package:reem/features/reputation/data/datasources/impl/reputation_remote_datasource_impl.dart';
import 'package:reem/features/reputation/data/datasources/reputation_remote_datasource.dart';
import 'package:reem/features/reputation/data/repositories/reputation_repository_impl.dart';
import 'package:reem/features/reputation/domain/entities/fit_entities.dart';
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

/// A product's reviews, all of them or narrowed to «من بمقاسي» / «مع صور».
///
/// Keyed by a record so the three lists are cached separately and switching
/// chips back and forth does not refetch.
final productReviewsProvider = FutureProvider.family<List<ReviewEntity>,
    ({String productId, ReviewFilter filter})>((ref, key) async {
  final result = await ref
      .watch(reputationRepositoryProvider)
      .getProductReviews(key.productId, filter: key.filter);
  return result.fold((failure) => throw failure.message, (reviews) => reviews);
});

/// «تقييمات من بمقاسي» — how the piece fits. Re-read when her profile
/// changes, because the "like you" half is computed against it.
final productFitProvider =
    FutureProvider.autoDispose.family<ProductFit, String>((ref, productId) async {
  ref.watch(fitProfileProvider);
  final result =
      await ref.watch(reputationRepositoryProvider).getProductFit(productId);
  return result.fold((failure) => throw failure.message, (fit) => fit);
});

/// «مقاساتي». Rebuilt with the account: one woman's height is not the next
/// one's.
final fitProfileProvider = FutureProvider<FitProfile>((ref) async {
  ref.watch(authNotifierProvider.select((s) => s.user?.id));
  final result = await ref.watch(reputationRepositoryProvider).getFitProfile();
  return result.fold((failure) => throw failure.message, (profile) => profile);
});

/// Everything she has written. `autoDispose` so leaving the screen and coming
/// back re-reads it — a review approved in the meantime should say so.
final myReviewsProvider = FutureProvider.autoDispose<MyReviews>((ref) async {
  final result = await ref.watch(reputationRepositoryProvider).getMyReviews();
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
  (ref) => ReputationActions(ref.watch(reputationRepositoryProvider), ref),
);

class ReputationActions {
  const ReputationActions(this.repository, this._ref);

  final ReputationRepository repository;
  final Ref _ref;

  Future<Result<ReviewEntity>> submitProductReview({
    required String productId,
    required int rating,
    String? title,
    String? body,
    String? orderId,
    ReviewFitInput? fit,
  }) async {
    final result = await repository.submitProductReview(
      productId: productId,
      rating: rating,
      title: title,
      body: body,
      orderId: orderId,
      fit: fit,
    );
    if (result is Success) {
      _ref.invalidate(productReviewsProvider);
      _ref.invalidate(productFitProvider(productId));
    }
    return result;
  }

  /// Save «مقاساتي». Every list and summary computed against the old profile
  /// is dropped, so «من بمقاسي» answers for the new one.
  Future<Result<FitProfile>> saveFitProfile({
    int? heightCm,
    String? usualSize,
    bool shareOnReviews = true,
  }) async {
    final result = await repository.saveFitProfile(
      heightCm: heightCm,
      usualSize: usualSize,
      shareOnReviews: shareOnReviews,
    );
    if (result is Success) {
      _ref.invalidate(fitProfileProvider);
      _ref.invalidate(productReviewsProvider);
    }
    return result;
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
