import 'package:reem/core/base/repository_handler.dart';
import 'package:reem/core/result/result.dart';

import '../../../discovery/domain/entities/product_page.dart';
import '../../domain/entities/search_suggestions.dart';
import '../../domain/repositories/search_repository.dart';
import '../datasources/search_remote_datasource.dart';

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
  Future<Result<List<String>>> trendingSearches() =>
      guard(remote.trendingSearches);

  @override
  Future<Result<SearchSuggestions>> searchSuggestions(String query) =>
      guard(() => remote.searchSuggestions(query));
}
