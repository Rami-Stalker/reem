import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:ohara/core/presentation/providers/core_providers.dart';
import 'package:ohara/core/result/result.dart';

import 'package:ohara/features/courier/data/datasources/courier_remote_datasource.dart';
import 'package:ohara/features/courier/data/datasources/impl/courier_remote_datasource_impl.dart';
import 'package:ohara/features/courier/data/repositories/courier_repository_impl.dart';
import 'package:ohara/features/courier/domain/entities/courier_assignment.dart';
import 'package:ohara/features/courier/domain/repositories/courier_repository.dart';

final courierRemoteDataSourceProvider = Provider<CourierRemoteDataSource>(
  (ref) => CourierRemoteDataSourceImpl(ref.watch(dioProvider)),
);

final courierRepositoryProvider = Provider<CourierRepository>(
  (ref) => CourierRepositoryImpl(ref.watch(courierRemoteDataSourceProvider)),
);

final courierDayNotifierProvider =
    StateNotifierProvider<CourierDayNotifier, CourierDayState>(
      (ref) => CourierDayNotifier(ref.watch(courierRepositoryProvider))..load(),
    );

class CourierDayState {
  const CourierDayState({
    this.assignments = const [],
    this.isLoading = false,
    this.busyId,
    this.error,
  });

  final List<CourierAssignment> assignments;
  final bool isLoading;

  /// The parcel currently being acted on, so only its own card shows a
  /// spinner rather than the whole round freezing.
  final String? busyId;
  final String? error;

  List<CourierAssignment> get open =>
      assignments.where((a) => !a.isClosed).toList(growable: false);

  List<CourierAssignment> get closed =>
      assignments.where((a) => a.isClosed).toList(growable: false);

  CourierDayState copyWith({
    List<CourierAssignment>? assignments,
    bool? isLoading,
    String? busyId,
    String? error,
    bool clearBusy = false,
    bool clearError = false,
  }) {
    return CourierDayState(
      assignments: assignments ?? this.assignments,
      isLoading: isLoading ?? this.isLoading,
      busyId: clearBusy ? null : (busyId ?? this.busyId),
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class CourierDayNotifier extends StateNotifier<CourierDayState> {
  CourierDayNotifier(this._repository) : super(const CourierDayState());

  final CourierRepository _repository;

  Future<void> load() async {
    state = state.copyWith(isLoading: true, clearError: true);
    final result = await _repository.today();
    switch (result) {
      case Success(:final data):
        state = state.copyWith(assignments: data, isLoading: false);
      case Error(:final failure):
        state = state.copyWith(isLoading: false, error: failure.message);
    }
  }

  Future<void> pickUp(String id) =>
      _act(id, () => _repository.pickUp(id));

  Future<void> startDelivery(String id) =>
      _act(id, () => _repository.startDelivery(id));

  Future<void> deliver(
    String id, {
    String? collected,
    String? recipientNote,
  }) => _act(
    id,
    () => _repository.deliver(
      id,
      collected: collected,
      recipientNote: recipientNote,
    ),
  );

  Future<void> fail(String id, DeliveryFailureReason reason, {String? note}) =>
      _act(id, () => _repository.fail(id, reason, note: note));

  /// Runs one action against one parcel, then reloads the round.
  ///
  /// Reloads rather than patching the list locally: the backend decides what
  /// a parcel's next state is, and a courier acting on a stale screen must see
  /// the truth rather than an optimistic guess that the server refused.
  Future<void> _act(String id, Future<Result<void>> Function() action) async {
    state = state.copyWith(busyId: id, clearError: true);
    final result = await action();
    if (result case Error(:final failure)) {
      state = state.copyWith(clearBusy: true, error: failure.message);
      return;
    }
    state = state.copyWith(clearBusy: true);
    await load();
  }

  void acknowledge() => state = state.copyWith(clearError: true);
}
