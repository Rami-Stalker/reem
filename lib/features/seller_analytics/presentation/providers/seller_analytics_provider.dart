import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import 'package:ohara/core/presentation/providers/core_providers.dart';
import 'package:ohara/core/result/result.dart';
import 'package:ohara/features/seller_analytics/data/datasources/impl/seller_analytics_remote_datasource_impl.dart';
import 'package:ohara/features/seller_analytics/data/datasources/seller_analytics_remote_datasource.dart';
import 'package:ohara/features/seller_analytics/data/repositories/seller_analytics_repository_impl.dart';
import 'package:ohara/features/seller_analytics/domain/entities/seller_analytics_report.dart';
import 'package:ohara/features/seller_analytics/domain/repositories/seller_analytics_repository.dart';

final sellerAnalyticsRemoteDataSourceProvider =
    Provider<SellerAnalyticsRemoteDataSource>(
      (ref) => SellerAnalyticsRemoteDataSourceImpl(ref.watch(dioProvider)),
    );

final sellerAnalyticsRepositoryProvider = Provider<SellerAnalyticsRepository>(
  (ref) => SellerAnalyticsRepositoryImpl(
    ref.watch(sellerAnalyticsRemoteDataSourceProvider),
  ),
);

class SellerAnalyticsState {
  const SellerAnalyticsState({
    this.period = AnalyticsPeriod.month,
    this.report,
    this.isLoading = false,
    this.error,
  });

  final AnalyticsPeriod period;
  final SellerAnalyticsReport? report;
  final bool isLoading;
  final String? error;

  /// A period switch keeps the previous figures on screen while the next ones
  /// load, so the page does not blink back to a spinner she has to wait out.
  bool get isInitialLoading => isLoading && report == null;

  SellerAnalyticsState copyWith({
    AnalyticsPeriod? period,
    SellerAnalyticsReport? report,
    bool? isLoading,
    String? error,
    bool clearError = false,
  }) => SellerAnalyticsState(
    period: period ?? this.period,
    report: report ?? this.report,
    isLoading: isLoading ?? this.isLoading,
    error: clearError ? null : (error ?? this.error),
  );
}

class SellerAnalyticsNotifier extends StateNotifier<SellerAnalyticsState> {
  SellerAnalyticsNotifier(this._repository)
    : super(const SellerAnalyticsState());

  final SellerAnalyticsRepository _repository;

  Future<void> load() async {
    state = state.copyWith(isLoading: true, clearError: true);
    final result = await _repository.dashboard(state.period);
    state = switch (result) {
      Success(:final data) => state.copyWith(isLoading: false, report: data),
      Error(:final failure) => state.copyWith(
        isLoading: false,
        error: failure.message,
      ),
    };
  }

  Future<void> refresh() => load();

  Future<void> setPeriod(AnalyticsPeriod period) async {
    if (period == state.period) return;
    state = state.copyWith(period: period);
    await load();
  }
}

final sellerAnalyticsNotifierProvider =
    StateNotifierProvider.autoDispose<
      SellerAnalyticsNotifier,
      SellerAnalyticsState
    >((ref) => SellerAnalyticsNotifier(
      ref.watch(sellerAnalyticsRepositoryProvider),
    )..load());
