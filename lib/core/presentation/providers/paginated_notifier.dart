import 'package:flutter_riverpod/legacy.dart';
import 'package:ohara/core/domain/pagination/paginated_data.dart';
import 'package:ohara/core/presentation/state/paginated_state.dart';
import 'package:ohara/core/result/result.dart';

typedef PageFetcher<T> =
    Future<Result<PaginatedData<T>>> Function(PageRequest request);

class PaginatedNotifier<T> extends StateNotifier<PaginatedState<T>> {
  PaginatedNotifier(this._fetch, {this.pageSize = 20})
    : super(PaginatedState<T>());

  final PageFetcher<T> _fetch;
  final int pageSize;

  /// A stable identity for a row, or null to keep every row as it comes.
  ///
  /// When given, a later page never repeats a row an earlier one already
  /// showed. A feed whose first page leads with a pinned (sponsored) post can
  /// meet that same post again organically further down, and two rows with
  /// one id are one card drawn twice — and one key used twice in a list.
  String? identityOf(T item) => null;

  List<T> _appendUnique(List<T> existing, List<T> incoming) {
    if (incoming.isEmpty || identityOf(incoming.first) == null) {
      return [...existing, ...incoming];
    }
    final seen = {for (final item in existing) identityOf(item)};
    return [
      ...existing,
      for (final item in incoming)
        if (seen.add(identityOf(item))) item,
    ];
  }

  /// Bumped by every load and refresh. A next page that was requested before
  /// the list was replaced belongs to the old list: appending it would put
  /// stale or duplicated rows under fresh ones, so it is dropped.
  int _generation = 0;

  Future<void> load() async {
    final generation = ++_generation;
    state = state.copyWith(isLoading: true, clearError: true);
    final result = await _fetch(PageRequest(limit: pageSize));
    // A screen she left disposes its list while the request is in flight.
    if (!mounted || generation != _generation) return;
    state = switch (result) {
      Success(:final data) => state.copyWith(
        isLoading: false,
        isRefreshing: false,
        isLoadingMore: false,
        items: data.items,
        pageInfo: data.pageInfo,
      ),
      Error(:final failure) => state.copyWith(
        isLoading: false,
        isRefreshing: false,
        isLoadingMore: false,
        error: failure.message,
        failure: failure,
      ),
    };
  }

  Future<void> refresh() async {
    final generation = ++_generation;
    state = state.copyWith(isRefreshing: true, clearError: true);
    final result = await _fetch(PageRequest(limit: pageSize));
    if (!mounted || generation != _generation) return;
    state = switch (result) {
      Success(:final data) => state.copyWith(
        isLoading: false,
        isRefreshing: false,
        isLoadingMore: false,
        items: data.items,
        pageInfo: data.pageInfo,
      ),
      Error(:final failure) => state.copyWith(
        isLoading: false,
        isRefreshing: false,
        isLoadingMore: false,
        error: failure.message,
        failure: failure,
      ),
    };
  }

  Future<void> loadMore() async {
    if (state.isLoadingMore ||
        state.isLoading ||
        state.isRefreshing ||
        !state.hasNextPage) {
      return;
    }
    final generation = _generation;
    state = state.copyWith(isLoadingMore: true, clearError: true);
    final request = PageRequest(
      page: state.page + 1,
      limit: pageSize,
      cursor: state.pageInfo.nextCursor,
    );
    final result = await _fetch(request);
    if (!mounted || generation != _generation) return;
    state = switch (result) {
      Success(:final data) => state.copyWith(
        isLoadingMore: false,
        items: _appendUnique(state.items, data.items),
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
