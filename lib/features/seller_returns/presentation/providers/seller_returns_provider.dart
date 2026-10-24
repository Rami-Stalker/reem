import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import 'package:ohara/core/errors/failure_exception.dart';
import 'package:ohara/core/presentation/providers/core_providers.dart';
import 'package:ohara/core/result/result.dart';
import 'package:ohara/features/seller_returns/data/datasources/impl/seller_returns_remote_datasource_impl.dart';
import 'package:ohara/features/seller_returns/data/datasources/seller_returns_remote_datasource.dart';
import 'package:ohara/features/seller_returns/data/repositories/seller_returns_repository_impl.dart';
import 'package:ohara/features/seller_returns/domain/entities/return_request.dart';
import 'package:ohara/features/seller_returns/domain/repositories/seller_returns_repository.dart';

final sellerReturnsRemoteDataSourceProvider =
    Provider<SellerReturnsRemoteDataSource>(
      (ref) => SellerReturnsRemoteDataSourceImpl(ref.watch(dioProvider)),
    );

final sellerReturnsRepositoryProvider = Provider<SellerReturnsRepository>(
  (ref) => SellerReturnsRepositoryImpl(
    ref.watch(sellerReturnsRemoteDataSourceProvider),
  ),
);

/// The three groups the desk is worked in.
///
/// Not one tab per server status: `REQUESTED`, `APPROVED` and `IN_TRANSIT` are
/// three different answers to the same question — is this still mine to move —
/// and splitting them would scatter one job across three tabs.
enum ReturnQueueTab { open, awaitingRefund, closed }

extension ReturnQueueTabX on ReturnQueueTab {
  bool accepts(ReturnRequest request) => switch (this) {
    ReturnQueueTab.open => request.status.needsSeller,
    ReturnQueueTab.awaitingRefund =>
      request.status == ReturnStatus.received ||
          request.status == ReturnStatus.exchanged,
    ReturnQueueTab.closed => request.status.isClosed,
  };
}

class SellerReturnsState {
  const SellerReturnsState({
    this.requests = const [],
    this.tab = ReturnQueueTab.open,
    this.isLoading = false,
    this.actingId,
    this.error,
  });

  final List<ReturnRequest> requests;
  final ReturnQueueTab tab;
  final bool isLoading;

  /// The request currently mid-transition, for a per-row spinner.
  final String? actingId;
  final String? error;

  List<ReturnRequest> get visible =>
      requests.where(tab.accepts).toList(growable: false);

  int countFor(ReturnQueueTab tab) => requests.where(tab.accepts).length;

  bool get isInitialLoading => isLoading && requests.isEmpty;

  SellerReturnsState copyWith({
    List<ReturnRequest>? requests,
    ReturnQueueTab? tab,
    bool? isLoading,
    String? actingId,
    String? error,
    bool clearError = false,
    bool clearActing = false,
  }) => SellerReturnsState(
    requests: requests ?? this.requests,
    tab: tab ?? this.tab,
    isLoading: isLoading ?? this.isLoading,
    actingId: clearActing ? null : (actingId ?? this.actingId),
    error: clearError ? null : (error ?? this.error),
  );
}

class SellerReturnsNotifier extends StateNotifier<SellerReturnsState> {
  SellerReturnsNotifier(this._repository) : super(const SellerReturnsState());

  final SellerReturnsRepository _repository;

  /// The whole queue is fetched once and grouped on the client.
  ///
  /// The endpoint filters by a single status, and the tabs each span several —
  /// three round trips to fill three badges, for a list that is a handful of
  /// rows in all but the largest shop.
  Future<void> load() async {
    state = state.copyWith(isLoading: true, clearError: true);
    final result = await _repository.queue();
    state = switch (result) {
      Success(:final data) => state.copyWith(isLoading: false, requests: data),
      Error(:final failure) => state.copyWith(
        isLoading: false,
        error: failure.message,
      ),
    };
  }

  Future<void> refresh() => load();

  void setTab(ReturnQueueTab tab) => state = state.copyWith(tab: tab);

  Future<bool> act(
    ReturnRequest request,
    ReturnAction action, {
    String? reason,
    String? note,
    bool? restock,
    ReturnCostBearer? shippingBorneBy,
  }) async {
    state = state.copyWith(actingId: request.id, clearError: true);
    final result = await _repository.act(
      request.id,
      action,
      reason: reason,
      note: note,
      restock: restock,
      shippingBorneBy: shippingBorneBy,
    );

    return switch (result) {
      Success(:final data) => () {
        state = state.copyWith(
          requests: [
            for (final row in state.requests) row.id == data.id ? data : row,
          ],
          clearActing: true,
        );
        return true;
      }(),
      Error(:final failure) => () {
        state = state.copyWith(error: failure.message, clearActing: true);
        return false;
      }(),
    };
  }
}

final sellerReturnsNotifierProvider =
    StateNotifierProvider.autoDispose<
      SellerReturnsNotifier,
      SellerReturnsState
    >((ref) => SellerReturnsNotifier(
      ref.watch(sellerReturnsRepositoryProvider),
    )..load());

/// One return, fetched on its own so the detail screen can be opened from a
/// notification without the queue having loaded first.
final sellerReturnProvider = FutureProvider.autoDispose
    .family<ReturnRequest, String>((ref, id) async {
      final result = await ref.watch(sellerReturnsRepositoryProvider).detail(id);
      return switch (result) {
        Success(:final data) => data,
        Error(:final failure) => throw FailureException(failure),
      };
    });
