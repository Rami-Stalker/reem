import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import 'package:reem/core/presentation/providers/core_providers.dart';
import 'package:reem/core/result/result.dart';
import 'package:reem/features/seller_reviews/data/datasources/impl/seller_reviews_remote_datasource_impl.dart';
import 'package:reem/features/seller_reviews/data/datasources/seller_reviews_remote_datasource.dart';
import 'package:reem/features/seller_reviews/data/repositories/seller_reviews_repository_impl.dart';
import 'package:reem/features/seller_reviews/domain/entities/seller_review.dart';
import 'package:reem/features/seller_reviews/domain/repositories/seller_reviews_repository.dart';

final sellerReviewsRemoteDataSourceProvider =
    Provider<SellerReviewsRemoteDataSource>(
      (ref) => SellerReviewsRemoteDataSourceImpl(ref.watch(dioProvider)),
    );

final sellerReviewsRepositoryProvider = Provider<SellerReviewsRepository>(
  (ref) => SellerReviewsRepositoryImpl(
    ref.watch(sellerReviewsRemoteDataSourceProvider),
  ),
);

class SellerReviewsState {
  const SellerReviewsState({
    this.desk = const SellerReviewDesk(),
    this.unansweredOnly = false,
    this.isLoading = false,
    this.replyingTo,
    this.error,
  });

  final SellerReviewDesk desk;
  final bool unansweredOnly;
  final bool isLoading;

  /// The review currently being answered, for a per-row spinner.
  final String? replyingTo;
  final String? error;

  bool get isInitialLoading => isLoading && desk.reviews.isEmpty;

  SellerReviewsState copyWith({
    SellerReviewDesk? desk,
    bool? unansweredOnly,
    bool? isLoading,
    String? replyingTo,
    String? error,
    bool clearError = false,
    bool clearReplying = false,
  }) => SellerReviewsState(
    desk: desk ?? this.desk,
    unansweredOnly: unansweredOnly ?? this.unansweredOnly,
    isLoading: isLoading ?? this.isLoading,
    replyingTo: clearReplying ? null : (replyingTo ?? this.replyingTo),
    error: clearError ? null : (error ?? this.error),
  );
}

class SellerReviewsNotifier extends StateNotifier<SellerReviewsState> {
  SellerReviewsNotifier(this._repository) : super(const SellerReviewsState());

  final SellerReviewsRepository _repository;

  Future<void> load() async {
    state = state.copyWith(isLoading: true, clearError: true);
    final result = await _repository.desk(
      unansweredOnly: state.unansweredOnly,
    );
    state = switch (result) {
      Success(:final data) => state.copyWith(isLoading: false, desk: data),
      Error(:final failure) => state.copyWith(
        isLoading: false,
        error: failure.message,
      ),
    };
  }

  Future<void> refresh() => load();

  Future<void> setUnansweredOnly(bool value) async {
    if (value == state.unansweredOnly) return;
    state = state.copyWith(unansweredOnly: value);
    await load();
  }

  /// Publishes her answer, or removes it when [reply] is empty.
  ///
  /// Returns the error to show, or null. The whole desk is refetched rather
  /// than the row patched: answering changes the unanswered count, and while
  /// the «بانتظار ردّك» filter is on it also changes which rows belong here
  /// at all.
  Future<String?> reply(SellerReviewItem review, String reply) async {
    state = state.copyWith(replyingTo: review.id, clearError: true);
    final result = await _repository.reply(review.id, review.target, reply);

    if (result case Error(:final failure)) {
      state = state.copyWith(error: failure.message, clearReplying: true);
      return failure.message;
    }

    await load();
    state = state.copyWith(clearReplying: true);
    return null;
  }
}

final sellerReviewsNotifierProvider =
    StateNotifierProvider.autoDispose<
      SellerReviewsNotifier,
      SellerReviewsState
    >((ref) => SellerReviewsNotifier(
      ref.watch(sellerReviewsRepositoryProvider),
    )..load());
