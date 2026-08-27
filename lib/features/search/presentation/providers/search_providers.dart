import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import 'package:reem/core/presentation/providers/core_providers.dart';
import 'package:reem/core/result/result.dart';
import 'package:reem/features/discovery/presentation/providers/collection_notifier.dart';
import 'package:reem/features/discovery/presentation/providers/collection_state.dart';
import 'package:reem/features/search/data/datasources/impl/search_remote_datasource_impl.dart';
import 'package:reem/features/search/data/datasources/search_remote_datasource.dart';
import 'package:reem/features/search/data/repositories/search_repository_impl.dart';
import 'package:reem/features/search/domain/entities/search_suggestions.dart';
import 'package:reem/features/search/domain/repositories/search_repository.dart';
import 'package:reem/features/search/domain/usecases/search_products_usecase.dart';

// ── Infrastructure / use cases ──────────────────────────────────────────────

final searchRemoteDataSourceProvider = Provider<SearchRemoteDataSource>(
  (ref) => SearchRemoteDataSourceImpl(ref.watch(dioProvider)),
);

final searchRepositoryProvider = Provider<SearchRepository>(
  (ref) => SearchRepositoryImpl(ref.watch(searchRemoteDataSourceProvider)),
);

final searchProductsUseCaseProvider = Provider(
  (ref) => SearchProductsUseCase(ref.watch(searchRepositoryProvider)),
);

/// Paginated results for a query. Reuses the discovery paging notifier so
/// loading / error / load-more behaviour stays identical across the app.
final searchResultsProvider = StateNotifierProvider.autoDispose
    .family<CollectionNotifier, CollectionState, String>((ref, query) {
      return CollectionNotifier(
        (page) => ref.read(searchProductsUseCaseProvider)(query, page: page),
      )..load();
    });

final trendingSearchesProvider = FutureProvider.autoDispose<List<String>>((
  ref,
) async {
  final result = await ref.watch(searchRepositoryProvider).trendingSearches();
  return switch (result) {
    Success(:final data) => data,
    Error() => const <String>[],
  };
});

final searchSuggestionsProvider = FutureProvider.autoDispose
    .family<SearchSuggestions, String>((ref, query) async {
      final trimmed = query.trim();
      if (trimmed.isEmpty) return const SearchSuggestions();
      final result = await ref
          .watch(searchRepositoryProvider)
          .searchSuggestions(trimmed);
      return switch (result) {
        Success(:final data) => data,
        Error() => const SearchSuggestions(),
      };
    });

/// Session-scoped recent searches (most recent first, capped).
final recentSearchesProvider =
    StateNotifierProvider<RecentSearchesNotifier, List<String>>(
      (ref) => RecentSearchesNotifier(),
    );

class RecentSearchesNotifier extends StateNotifier<List<String>> {
  RecentSearchesNotifier() : super(const []);

  static const _max = 8;

  void add(String term) {
    final t = term.trim();
    if (t.isEmpty) return;
    final next = [t, ...state.where((e) => e.toLowerCase() != t.toLowerCase())];
    state = next.take(_max).toList();
  }

  void remove(String term) => state = state.where((e) => e != term).toList();

  void clear() => state = const [];
}
