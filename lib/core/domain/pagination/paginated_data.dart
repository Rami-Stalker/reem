import 'package:equatable/equatable.dart';

final class PageRequest extends Equatable {
  const PageRequest({
    this.page = 1,
    this.limit = 20,
    this.cursor,
    this.sort,
    this.filters = const {},
  }) : assert(page >= 1, 'Page must start at 1.'),
       assert(limit >= 1, 'Limit must be positive.');

  final int page;
  final int limit;
  final String? cursor;
  final String? sort;
  final Map<String, Object?> filters;

  PageRequest next({String? cursor}) => PageRequest(
    page: page + 1,
    limit: limit,
    cursor: cursor ?? this.cursor,
    sort: sort,
    filters: filters,
  );

  Map<String, dynamic> toQuery() => {
    'page': page,
    'limit': limit,
    if (cursor != null) 'cursor': cursor,
    if (sort != null) 'sort': sort,
    ...filters,
  };

  @override
  List<Object?> get props => [page, limit, cursor, sort, filters];
}

final class PageInfo extends Equatable {
  const PageInfo({
    this.page = 0,
    this.limit = 20,
    this.totalItems,
    this.totalPages,
    this.hasNextPage = false,
    this.nextCursor,
  });

  final int page;
  final int limit;
  final int? totalItems;
  final int? totalPages;
  final bool hasNextPage;
  final String? nextCursor;

  static const empty = PageInfo();

  PageRequest nextRequest() =>
      PageRequest(page: page + 1, limit: limit, cursor: nextCursor);

  @override
  List<Object?> get props => [
    page,
    limit,
    totalItems,
    totalPages,
    hasNextPage,
    nextCursor,
  ];
}

final class PaginatedData<T> extends Equatable {
  const PaginatedData({required this.items, required this.pageInfo});

  final List<T> items;
  final PageInfo pageInfo;

  static PaginatedData<T> empty<T>() =>
      PaginatedData<T>(items: const [], pageInfo: PageInfo.empty);

  int get page => pageInfo.page;
  bool get hasNextPage => pageInfo.hasNextPage;

  PaginatedData<T> append(PaginatedData<T> next) => PaginatedData<T>(
    items: [...items, ...next.items],
    pageInfo: next.pageInfo,
  );

  @override
  List<Object?> get props => [items, pageInfo];
}
