import 'package:ohara/core/domain/pagination/paginated_data.dart';
import 'package:ohara/core/errors/failure.dart';

class PaginatedState<T> {
  const PaginatedState({
    this.isLoading = false,
    this.isRefreshing = false,
    this.isLoadingMore = false,
    this.items = const [],
    this.pageInfo = PageInfo.empty,
    this.error,
    this.failure,
  });

  final bool isLoading;
  final bool isRefreshing;
  final bool isLoadingMore;
  final List<T> items;
  final PageInfo pageInfo;
  final String? error;
  final Failure? failure;

  int get page => pageInfo.page;
  bool get hasNextPage => pageInfo.hasNextPage;
  bool get isEmpty => !isLoading && items.isEmpty;
  bool get hasError => error != null && items.isEmpty;
  bool get hasFailure => failure != null;

  PaginatedState<T> copyWith({
    bool? isLoading,
    bool? isRefreshing,
    bool? isLoadingMore,
    List<T>? items,
    PageInfo? pageInfo,
    String? error,
    Failure? failure,
    bool clearError = false,
  }) {
    return PaginatedState<T>(
      isLoading: isLoading ?? this.isLoading,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      items: items ?? this.items,
      pageInfo: pageInfo ?? this.pageInfo,
      error: clearError ? null : (error ?? this.error),
      failure: clearError ? null : (failure ?? this.failure),
    );
  }
}
