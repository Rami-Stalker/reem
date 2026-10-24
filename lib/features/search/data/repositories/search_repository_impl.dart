import 'package:ohara/core/base/repository_handler.dart';
import 'package:ohara/core/domain/pagination/paginated_data.dart';
import 'package:ohara/core/result/result.dart';
import 'package:ohara/core/shared/entities/post.dart';
import 'package:ohara/core/shared/entities/user.dart';
import 'package:ohara/features/discovery/domain/entities/product_page.dart';
import 'package:ohara/features/search/data/datasources/search_remote_datasource.dart';
import 'package:ohara/features/search/domain/entities/search_suggestions.dart';
import 'package:ohara/features/search/domain/entities/unified_search.dart';
import 'package:ohara/features/search/domain/repositories/search_repository.dart';

class SearchRepositoryImpl with RepositoryHandler implements SearchRepository {
  const SearchRepositoryImpl(this.remote);

  final SearchRemoteDataSource remote;

  @override
  Future<Result<ProductPage>> searchProducts(
    String query, {
    int page = 1,
    int limit = 20,
  }) => guard(() => remote.searchProducts(query, page: page, limit: limit));

  @override
  Future<Result<UnifiedSearch>> searchAll(String query) =>
      guard(() => remote.searchAll(query), operation: 'search all');

  @override
  Future<Result<PaginatedData<User>>> searchBoutiques(
    String query, {
    int page = 1,
    int limit = 20,
  }) => guard(() => remote.searchBoutiques(query, page: page, limit: limit));

  @override
  Future<Result<PaginatedData<User>>> searchShoppers(
    String query, {
    int page = 1,
    int limit = 20,
  }) => guard(() => remote.searchShoppers(query, page: page, limit: limit));

  @override
  Future<Result<PaginatedData<Post>>> searchPosts(
    String query, {
    int page = 1,
    int limit = 20,
  }) => guard(() => remote.searchPosts(query, page: page, limit: limit));

  @override
  Future<Result<List<String>>> trendingSearches() =>
      guard(remote.trendingSearches);

  @override
  Future<Result<SearchSuggestions>> searchSuggestions(String query) =>
      guard(() => remote.searchSuggestions(query));
}
