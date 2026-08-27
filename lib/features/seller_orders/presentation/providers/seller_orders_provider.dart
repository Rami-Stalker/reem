import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:reem/core/network/network_info.dart';
import 'package:reem/core/providers/core_providers.dart';
import 'package:reem/core/result/result.dart';

import '../../data/datasources/impl/seller_orders_remote_datasource_impl.dart';
import '../../data/datasources/seller_orders_remote_datasource.dart';
import '../../data/repositories/seller_orders_repository_impl.dart';
import '../../domain/entities/seller_order.dart';
import '../../domain/repositories/seller_orders_repository.dart';

final sellerOrdersRemoteDataSourceProvider =
    Provider<SellerOrdersRemoteDataSource>(
      (ref) => SellerOrdersRemoteDataSourceImpl(ref.watch(dioProvider)),
    );

final sellerOrdersRepositoryProvider = Provider<SellerOrdersRepository>(
  (ref) =>
      SellerOrdersRepositoryImpl(ref.watch(sellerOrdersRemoteDataSourceProvider)),
);

final sellerOrdersNotifierProvider =
    StateNotifierProvider.autoDispose<SellerOrdersNotifier, SellerOrdersState>(
      (ref) => SellerOrdersNotifier(
        repository: ref.watch(sellerOrdersRepositoryProvider),
        networkInfo: ref.watch(networkInfoProvider),
      )..load(),
    );

/// One parcel's detail, kept per id so two open orders cannot overwrite each
/// other's state.
final sellerOrderDetailProvider = StateNotifierProvider.autoDispose
    .family<SellerOrderDetailNotifier, SellerOrderDetailState, String>(
      (ref, id) => SellerOrderDetailNotifier(
        id: id,
        repository: ref.watch(sellerOrdersRepositoryProvider),
        networkInfo: ref.watch(networkInfoProvider),
        onChanged: () =>
            ref.read(sellerOrdersNotifierProvider.notifier).refresh(),
      )..load(),
    );

/// A client-side problem, as a code the screen localises. Never an English
/// sentence in the state — the UI is Arabic and the state is not the place to
/// decide wording.
enum SellerOrdersIssue { offline }

class SellerOrdersState {
  const SellerOrdersState({
    this.queue,
    this.tab = SellerQueueTab.newOrders,
    this.isLoading = false,
    this.isRefreshing = false,
    this.busyOrderId,
    this.issue,
    this.serverError,
  });

  final SellerOrderQueue? queue;
  final SellerQueueTab tab;
  final bool isLoading;
  final bool isRefreshing;

  /// The parcel whose action is in flight, so only its card shows a spinner
  /// instead of the whole list going grey.
  final String? busyOrderId;

  final SellerOrdersIssue? issue;
  final String? serverError;

  List<SellerOrderSummary> get orders => queue?.orders ?? const [];

  int countFor(SellerQueueTab tab) => queue?.countFor(tab) ?? 0;

  SellerOrdersState copyWith({
    SellerOrderQueue? queue,
    SellerQueueTab? tab,
    bool? isLoading,
    bool? isRefreshing,
    String? busyOrderId,
    SellerOrdersIssue? issue,
    String? serverError,
    bool clearBusy = false,
    bool clearIssue = false,
    bool clearServerError = false,
  }) {
    return SellerOrdersState(
      queue: queue ?? this.queue,
      tab: tab ?? this.tab,
      isLoading: isLoading ?? this.isLoading,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      busyOrderId: clearBusy ? null : (busyOrderId ?? this.busyOrderId),
      issue: clearIssue ? null : (issue ?? this.issue),
      serverError: clearServerError ? null : (serverError ?? this.serverError),
    );
  }
}

/// The seller's queue.
///
/// Actions reload the queue instead of patching the row in place. That is not
/// laziness: a confirmed parcel leaves the "new" tab, the badge counts change
/// with it, and the server is the only thing that knows what the parcel may do
/// next. Patching locally would show her a card in the wrong tab with the
/// wrong buttons until something else happened to refresh it.
class SellerOrdersNotifier extends StateNotifier<SellerOrdersState> {
  SellerOrdersNotifier({
    required SellerOrdersRepository repository,
    required NetworkInfo networkInfo,
  }) : _repository = repository,
       _networkInfo = networkInfo,
       super(const SellerOrdersState());

  final SellerOrdersRepository _repository;
  final NetworkInfo _networkInfo;

  Future<void> load({bool refresh = false}) async {
    if (!await _networkInfo.isConnected) {
      state = state.copyWith(
        isLoading: false,
        isRefreshing: false,
        issue: SellerOrdersIssue.offline,
      );
      return;
    }

    state = state.copyWith(
      isLoading: !refresh && state.queue == null,
      isRefreshing: refresh,
      clearIssue: true,
      clearServerError: true,
    );

    final result = await _repository.queue(tab: state.tab);
    switch (result) {
      case Success(:final data):
        state = state.copyWith(
          queue: data,
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

  Future<void> selectTab(SellerQueueTab tab) async {
    if (tab == state.tab) return;
    state = state.copyWith(tab: tab, isRefreshing: true);
    await load(refresh: true);
  }

  /// Runs an action and reloads. Returns false when the server refused, so the
  /// caller can surface [SellerOrdersState.serverError] without racing it.
  Future<bool> run(
    SellerOrderSummary order,
    SellerOrderAction action, {
    String? reason,
    String? collected,
    String? carrier,
  }) async {
    state = state.copyWith(busyOrderId: order.id, clearServerError: true);

    final result = await _repository.act(
      order.id,
      action,
      reason: reason,
      collected: collected,
      carrier: carrier,
    );

    switch (result) {
      case Success():
        state = state.copyWith(clearBusy: true);
        await load(refresh: true);
        return true;
      case Error(:final failure):
        state = state.copyWith(clearBusy: true, serverError: failure.message);
        return false;
    }
  }
}

class SellerOrderDetailState {
  const SellerOrderDetailState({
    this.order,
    this.isLoading = false,
    this.isBusy = false,
    this.issue,
    this.serverError,
  });

  final SellerOrderDetail? order;
  final bool isLoading;
  final bool isBusy;
  final SellerOrdersIssue? issue;
  final String? serverError;

  SellerOrderDetailState copyWith({
    SellerOrderDetail? order,
    bool? isLoading,
    bool? isBusy,
    SellerOrdersIssue? issue,
    String? serverError,
    bool clearIssue = false,
    bool clearServerError = false,
  }) {
    return SellerOrderDetailState(
      order: order ?? this.order,
      isLoading: isLoading ?? this.isLoading,
      isBusy: isBusy ?? this.isBusy,
      issue: clearIssue ? null : (issue ?? this.issue),
      serverError: clearServerError ? null : (serverError ?? this.serverError),
    );
  }
}

class SellerOrderDetailNotifier extends StateNotifier<SellerOrderDetailState> {
  SellerOrderDetailNotifier({
    required String id,
    required SellerOrdersRepository repository,
    required NetworkInfo networkInfo,
    required this.onChanged,
  }) : _id = id,
       _repository = repository,
       _networkInfo = networkInfo,
       super(const SellerOrderDetailState());

  final String _id;
  final SellerOrdersRepository _repository;
  final NetworkInfo _networkInfo;

  /// Told after every successful action so the queue behind this screen does
  /// not go stale while she is looking at it.
  final void Function() onChanged;

  Future<void> load() async {
    if (!await _networkInfo.isConnected) {
      state = state.copyWith(
        isLoading: false,
        issue: SellerOrdersIssue.offline,
      );
      return;
    }

    state = state.copyWith(
      isLoading: state.order == null,
      clearIssue: true,
      clearServerError: true,
    );

    final result = await _repository.detail(_id);
    switch (result) {
      case Success(:final data):
        state = state.copyWith(order: data, isLoading: false);
      case Error(:final failure):
        state = state.copyWith(isLoading: false, serverError: failure.message);
    }
  }

  Future<bool> run(
    SellerOrderAction action, {
    String? reason,
    String? collected,
    String? carrier,
  }) async {
    state = state.copyWith(isBusy: true, clearServerError: true);

    final result = await _repository.act(
      _id,
      action,
      reason: reason,
      collected: collected,
      carrier: carrier,
    );

    switch (result) {
      case Success(:final data):
        // The response *is* the new state, so nothing is inferred locally
        // about what the transition produced.
        state = state.copyWith(order: data, isBusy: false);
        onChanged();
        return true;
      case Error(:final failure):
        state = state.copyWith(isBusy: false, serverError: failure.message);
        return false;
    }
  }
}
