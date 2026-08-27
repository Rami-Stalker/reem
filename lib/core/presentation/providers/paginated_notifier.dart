import 'package:flutter_riverpod/legacy.dart';
import 'package:reem/core/domain/pagination/paginated_data.dart';
import 'package:reem/core/presentation/state/paginated_state.dart';
import 'package:reem/core/result/result.dart';

typedef PageFetcher<T> =
    Future<Result<PaginatedData<T>>> Function(PageRequest request);

class PaginatedNotifier<T> extends StateNotifier<PaginatedState<T>> {
  PaginatedNotifier(this._fetch, {this.pageSize = 20})
    : super(PaginatedState<T>());

  final PageFetcher<T> _fetch;
  final int pageSize;

  Future<void> load() async {
    state = state.copyWith(isLoading: true, clearError: true);
    final result = await _fetch(PageRequest(limit: pageSize));
    state = switch (result) {
      Success(:final data) => state.copyWith(
        isLoading: false,
        items: data.items,
        pageInfo: data.pageInfo,
      ),
      Error(:final failure) => state.copyWith(
        isLoading: false,
        error: failure.message,
        failure: failure,
      ),
    };
  }

  Future<void> refresh() async {
    state = state.copyWith(isRefreshing: true, clearError: true);
    final result = await _fetch(PageRequest(limit: pageSize));
    state = switch (result) {
      Success(:final data) => state.copyWith(
        isRefreshing: false,
        items: data.items,
        pageInfo: data.pageInfo,
      ),
      Error(:final failure) => state.copyWith(
        isRefreshing: false,
        error: failure.message,
        failure: failure,
      ),
    };
  }

  Future<void> loadMore() async {
    if (state.isLoadingMore || state.isLoading || !state.hasNextPage) return;
    state = state.copyWith(isLoadingMore: true, clearError: true);
    final request = PageRequest(
      page: state.page + 1,
      limit: pageSize,
      cursor: state.pageInfo.nextCursor,
    );
    final result = await _fetch(request);
    state = switch (result) {
      Success(:final data) => state.copyWith(
        isLoadingMore: false,
        items: [...state.items, ...data.items],
        pageInfo: data.pageInfo,
      ),
      Error(:final failure) => state.copyWith(
        isLoadingMore: false,
        error: failure.message,
        failure: failure,
      ),
    };
  }
}
