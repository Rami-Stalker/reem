import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:reem/core/network/network_info.dart';
import 'package:reem/core/presentation/providers/core_providers.dart';
import 'package:reem/core/result/result.dart';

import '../../data/datasources/impl/seller_earnings_remote_datasource_impl.dart';
import '../../data/datasources/seller_earnings_remote_datasource.dart';
import '../../data/repositories/seller_earnings_repository_impl.dart';
import '../../domain/entities/seller_earnings.dart';
import '../../domain/repositories/seller_earnings_repository.dart';

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
    this.isLoading = false,
    this.isRefreshing = false,
    this.issue,
    this.serverError,
  });

  final SellerEarnings? earnings;
  final bool isLoading;
  final bool isRefreshing;
  final SellerEarningsIssue? issue;
  final String? serverError;

  SellerEarningsState copyWith({
    SellerEarnings? earnings,
    bool? isLoading,
    bool? isRefreshing,
    SellerEarningsIssue? issue,
    String? serverError,
    bool clearIssue = false,
    bool clearServerError = false,
  }) {
    return SellerEarningsState(
      earnings: earnings ?? this.earnings,
      isLoading: isLoading ?? this.isLoading,
      isRefreshing: isRefreshing ?? this.isRefreshing,
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

    final result = await _repository.load();
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
  }

  Future<void> refresh() => load(refresh: true);
}
