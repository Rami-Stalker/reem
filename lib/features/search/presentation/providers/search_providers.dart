import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import 'package:ohara/core/errors/failure_exception.dart';
import 'package:ohara/core/presentation/providers/core_providers.dart';
import 'package:ohara/core/presentation/providers/paginated_notifier.dart';
import 'package:ohara/core/presentation/state/paginated_state.dart';
import 'package:ohara/core/result/result.dart';
import 'package:ohara/core/shared/entities/post.dart';
import 'package:ohara/core/shared/entities/user.dart';
import 'package:ohara/features/discovery/presentation/providers/collection_notifier.dart';
import 'package:ohara/features/discovery/presentation/providers/collection_state.dart';
import 'package:ohara/features/discovery/presentation/providers/sponsored_providers.dart';
import 'package:ohara/features/search/data/datasources/impl/search_remote_datasource_impl.dart';
import 'package:ohara/features/search/data/datasources/search_remote_datasource.dart';
import 'package:ohara/features/search/data/repositories/search_repository_impl.dart';
import 'package:ohara/features/search/domain/entities/search_suggestions.dart';
import 'package:ohara/features/search/domain/entities/unified_search.dart';
import 'package:ohara/features/search/domain/repositories/search_repository.dart';
import 'package:ohara/features/search/domain/usecases/search_products_usecase.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
      return CollectionNotifier((page) async {
        final result = await ref.read(searchProductsUseCaseProvider)(
          query,
          page: page,
        );
        // The paid slots arrive with page one and are handed to the screen
        // from this same response — see [sponsoredSlotsProvider].
        if (page == 1 && ref.mounted) {
          if (result case Success(:final data)) {
            ref
                    .read(sponsoredSlotsProvider(searchSponsoredKey(query)).notifier)
                    .state =
                data.sponsored;
          }
        }
        return result;
      })..load();
    });

/// The top hits in every kind, for the «الكل» tab.
final unifiedSearchProvider = FutureProvider.autoDispose
    .family<UnifiedSearch, String>((ref, query) async {
      final result = await ref.watch(searchRepositoryProvider).searchAll(query);
      return switch (result) {
        Success(:final data) => data,
        Error(:final failure) => throw FailureException(failure),
      };
    });

final boutiqueSearchProvider = StateNotifierProvider.autoDispose
    .family<PaginatedNotifier<User>, PaginatedState<User>, String>((
      ref,
      query,
    ) {
      final repository = ref.watch(searchRepositoryProvider);
      return PaginatedNotifier<User>(
        (request) => repository.searchBoutiques(
          query,
          page: request.page,
          limit: request.limit,
        ),
      )..load();
    });

final shopperSearchProvider = StateNotifierProvider.autoDispose
    .family<PaginatedNotifier<User>, PaginatedState<User>, String>((
      ref,
      query,
    ) {
      final repository = ref.watch(searchRepositoryProvider);
      return PaginatedNotifier<User>(
        (request) => repository.searchShoppers(
          query,
          page: request.page,
          limit: request.limit,
        ),
      )..load();
    });

final postSearchProvider = StateNotifierProvider.autoDispose
    .family<PaginatedNotifier<Post>, PaginatedState<Post>, String>((
      ref,
      query,
    ) {
      final repository = ref.watch(searchRepositoryProvider);
      return PaginatedNotifier<Post>(
        (request) => repository.searchPosts(
          query,
          page: request.page,
          limit: request.limit,
        ),
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

/// Her recent searches, most recent first, capped — kept on this phone.
///
/// They used to live in memory only, so the list she built up was gone the
/// next time she opened the app, which is exactly when it is useful. Stored
/// locally rather than on the server on purpose: a woman's search history is
/// hers, and this list needs nothing an account would add.
final recentSearchesProvider =
    StateNotifierProvider<RecentSearchesNotifier, List<String>>(
      (ref) => RecentSearchesNotifier()..restore(),
    );

class RecentSearchesNotifier extends StateNotifier<List<String>> {
  RecentSearchesNotifier({RecentSearchesStore? store})
    : _store = store ?? const RecentSearchesStore(),
      super(const []);

  static const _max = 8;

  final RecentSearchesStore _store;

  /// Loads what was saved, without overwriting anything typed meanwhile.
  Future<void> restore() async {
    final saved = await _store.read();
    if (!mounted || saved.isEmpty) return;
    final merged = [
      ...state,
      ...saved.where(
        (term) => !state.any((e) => e.toLowerCase() == term.toLowerCase()),
      ),
    ];
    state = merged.take(_max).toList();
  }

  void add(String term) {
    final t = term.trim();
    if (t.isEmpty) return;
    final next = [t, ...state.where((e) => e.toLowerCase() != t.toLowerCase())];
    _set(next.take(_max).toList());
  }

  void remove(String term) => _set(state.where((e) => e != term).toList());

  void clear() => _set(const []);

  void _set(List<String> next) {
    state = next;
    _store.write(next);
  }
}

/// Where the list lives between launches. Failures are swallowed: losing the
/// list is a small inconvenience, and a search that threw because a preference
/// write failed would be a broken search.
class RecentSearchesStore {
  const RecentSearchesStore();

  // l10n-ignore: a storage key
  static const _key = 'search.recent.v1';

  Future<List<String>> read() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getStringList(_key) ?? const [];
    } catch (_) {
      return const [];
    }
  }

  Future<void> write(List<String> terms) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_key, terms);
    } catch (_) {
      // See the class comment.
    }
  }
}
