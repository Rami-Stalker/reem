import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:ohara/core/network/network_info.dart';
import 'package:ohara/core/presentation/providers/core_providers.dart';
import 'package:ohara/core/result/result.dart';

import 'package:ohara/features/seller_earnings/data/datasources/impl/seller_earnings_remote_datasource_impl.dart';
import 'package:ohara/features/seller_earnings/data/datasources/seller_earnings_remote_datasource.dart';
import 'package:ohara/features/seller_earnings/data/repositories/seller_earnings_repository_impl.dart';
import 'package:ohara/features/seller_earnings/domain/entities/seller_earnings.dart';
import 'package:ohara/features/seller_earnings/domain/repositories/seller_earnings_repository.dart';

final sellerEarningsRemoteDataSourceProvider =
    Provider<SellerEarningsRemoteDataSource>(
      (ref) => SellerEarningsRemoteDataSourceImpl(ref.watch(dioProvider)),
    );

final sellerEarningsRepositoryProvider = Provider<SellerEarningsRepository>(
  (ref) => SellerEarningsRepositoryImpl(
    ref.watch(sellerEarningsRemoteDataSourceProvider),
  ),
);

final sellerEarningsNotifierProvider =
    StateNotifierProvider.autoDispose<
      SellerEarningsNotifier,
      SellerEarningsState
    >(
      (ref) => SellerEarningsNotifier(
        repository: ref.watch(sellerEarningsRepositoryProvider),
        networkInfo: ref.watch(networkInfoProvider),
      )..load(),
    );

/// A client-side problem, as a code the screen localises.
enum SellerEarningsIssue { offline }

class SellerEarningsState {
  const SellerEarningsState({
    this.earnings,
    this.availability,
    this.isLoading = false,
    this.isRefreshing = false,
    this.isSubmittingPayout = false,
    this.issue,
    this.serverError,
  });

  final SellerEarnings? earnings;

  /// Null until the availability call lands. The withdrawal card waits for it
  /// rather than guessing from the balance: what is payable and what is
  /// *claimable right now* are different questions, and only the server can
  /// answer the second.
  final PayoutAvailability? availability;
  final bool isLoading;
  final bool isRefreshing;
  final bool isSubmittingPayout;
  final SellerEarningsIssue? issue;
  final String? serverError;

  SellerEarningsState copyWith({
    SellerEarnings? earnings,
    PayoutAvailability? availability,
    bool? isLoading,
    bool? isRefreshing,
    bool? isSubmittingPayout,
    SellerEarningsIssue? issue,
    String? serverError,
    bool clearIssue = false,
    bool clearServerError = false,
  }) {
    return SellerEarningsState(
      earnings: earnings ?? this.earnings,
      availability: availability ?? this.availability,
      isLoading: isLoading ?? this.isLoading,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      isSubmittingPayout: isSubmittingPayout ?? this.isSubmittingPayout,
      issue: clearIssue ? null : (issue ?? this.issue),
      serverError: clearServerError ? null : (serverError ?? this.serverError),
    );
  }
}

class SellerEarningsNotifier extends StateNotifier<SellerEarningsState> {
  SellerEarningsNotifier({
    required SellerEarningsRepository repository,
    required NetworkInfo networkInfo,
  }) : _repository = repository,
       _networkInfo = networkInfo,
       super(const SellerEarningsState());

  final SellerEarningsRepository _repository;
  final NetworkInfo _networkInfo;

  Future<void> load({bool refresh = false}) async {
    if (!await _networkInfo.isConnected) {
      state = state.copyWith(
        isLoading: false,
        isRefreshing: false,
        issue: SellerEarningsIssue.offline,
      );
      return;
    }

    state = state.copyWith(
      isLoading: !refresh && state.earnings == null,
      isRefreshing: refresh,
      clearIssue: true,
      clearServerError: true,
    );

    // The statement and what she may withdraw are fetched together: a screen
    // that showed a balance before it knew whether she could ask for it would
    // have to draw the withdrawal card twice.
    final (result, availability) = await (
      _repository.load(),
      _repository.payoutAvailability(),
    ).wait;

    switch (result) {
      case Success(:final data):
        state = state.copyWith(
          earnings: data,
          isLoading: false,
          isRefreshing: false,
        );
      case Error(:final failure):
        state = state.copyWith(
          isLoading: false,
          isRefreshing: false,
          serverError: failure.message,
        );
    }

    // Availability failing on its own is not worth an error page over a
    // statement that loaded: the card simply does not offer the button.
    if (availability case Success(:final data)) {
      state = state.copyWith(availability: data);
    }
  }

  Future<void> refresh() => load(refresh: true);

  /// Asks to be paid everything released.
  ///
  /// Returns the error to show, or null on success. No money moves here — the
  /// request goes into the platform's approval queue (Q62), and the screen
  /// says so rather than implying she has been paid.
  Future<String?> requestPayout() async {
    if (state.isSubmittingPayout) return null;
    state = state.copyWith(isSubmittingPayout: true, clearServerError: true);

    final result = await _repository.requestPayout();
    state = state.copyWith(isSubmittingPayout: false);

    return switch (result) {
      Success() => await _reload(),
      Error(:final failure) => failure.message,
    };
  }

  /// Withdraws a request nobody has approved yet.
  Future<String?> cancelPayout(String id) async {
    if (state.isSubmittingPayout) return null;
    state = state.copyWith(isSubmittingPayout: true, clearServerError: true);

    final result = await _repository.cancelPayout(id);
    state = state.copyWith(isSubmittingPayout: false);

    return switch (result) {
      Success() => await _reload(),
      Error(:final failure) => failure.message,
    };
  }

  /// Both figures move when a request is made or withdrawn — the balance is
  /// unchanged but what is claimable is not — so the whole page is refetched
  /// rather than patched from the response.
  Future<String?> _reload() async {
    await load(refresh: true);
    return null;
  }
}
