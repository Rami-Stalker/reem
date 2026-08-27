import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:reem/core/providers/core_providers.dart';
import 'package:reem/core/result/result.dart';

import '../../data/datasources/admin_finance_remote_datasource.dart';
import '../../data/datasources/impl/admin_finance_remote_datasource_impl.dart';
import '../../data/repositories/admin_finance_repository_impl.dart';
import '../../domain/entities/finance_overview.dart';
import '../../domain/repositories/admin_finance_repository.dart';

final adminFinanceRemoteDataSourceProvider =
    Provider<AdminFinanceRemoteDataSource>(
      (ref) => AdminFinanceRemoteDataSourceImpl(ref.watch(dioProvider)),
    );

final adminFinanceRepositoryProvider = Provider<AdminFinanceRepository>(
  (ref) =>
      AdminFinanceRepositoryImpl(ref.watch(adminFinanceRemoteDataSourceProvider)),
);

final adminFinanceNotifierProvider =
    StateNotifierProvider<AdminFinanceNotifier, AdminFinanceState>(
      (ref) => AdminFinanceNotifier(ref.watch(adminFinanceRepositoryProvider)),
    );

class AdminFinanceState {
  const AdminFinanceState({
    this.overview,
    this.isLoading = false,
    this.isRefreshing = false,
    this.isSyncingRate = false,
    this.error,
    this.notice,
  });

  final FinanceOverview? overview;
  final bool isLoading;
  final bool isRefreshing;
  final bool isSyncingRate;
  final String? error;

  /// A one-shot outcome to surface, e.g. why a rate sync published nothing.
  final String? notice;

  AdminFinanceState copyWith({
    FinanceOverview? overview,
    bool? isLoading,
    bool? isRefreshing,
    bool? isSyncingRate,
    String? error,
    String? notice,
    bool clearError = false,
    bool clearNotice = false,
  }) {
    return AdminFinanceState(
      overview: overview ?? this.overview,
      isLoading: isLoading ?? this.isLoading,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      isSyncingRate: isSyncingRate ?? this.isSyncingRate,
      error: clearError ? null : (error ?? this.error),
      notice: clearNotice ? null : (notice ?? this.notice),
    );
  }
}

class AdminFinanceNotifier extends StateNotifier<AdminFinanceState> {
  AdminFinanceNotifier(this._repository) : super(const AdminFinanceState());

  final AdminFinanceRepository _repository;

  Future<void> load({bool refresh = false}) async {
    state = state.copyWith(
      isLoading: !refresh && state.overview == null,
      isRefreshing: refresh,
      clearError: true,
    );

    final result = await _repository.loadOverview();
    switch (result) {
      case Success(:final data):
        state = state.copyWith(
          overview: data,
          isLoading: false,
          isRefreshing: false,
        );
      case Error(:final failure):
        state = state.copyWith(
          isLoading: false,
          isRefreshing: false,
          error: failure.message,
        );
    }
  }

  Future<void> refresh() => load(refresh: true);

  /// Q47/Q50 — pull the rate now rather than waiting for the morning run.
  Future<void> syncExchangeRate() async {
    state = state.copyWith(
      isSyncingRate: true,
      clearError: true,
      clearNotice: true,
    );

    final result = await _repository.syncExchangeRate();
    switch (result) {
      case Success(:final data):
        state = state.copyWith(isSyncingRate: false, notice: data);
        // A published rate changes every translated figure on the screen.
        await load(refresh: true);
      case Error(:final failure):
        state = state.copyWith(
          isSyncingRate: false,
          error: failure.message,
        );
    }
  }

  void acknowledge() =>
      state = state.copyWith(clearNotice: true, clearError: true);
}
