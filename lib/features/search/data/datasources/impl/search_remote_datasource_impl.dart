import 'package:reem/core/network/api_endpoints.dart';
import 'package:reem/core/network/base_remote_datasource.dart';
import 'package:reem/features/discovery/data/models/product_page_model.dart';
import 'package:reem/features/search/data/datasources/search_remote_datasource.dart';
import 'package:reem/features/search/domain/entities/search_suggestions.dart';

final class SearchRemoteDataSourceImpl extends BaseRemoteDataSource
    implements SearchRemoteDataSource {
  const SearchRemoteDataSourceImpl(super.dio);

  @override
  Future<ProductPageModel> searchProducts(
    String query, {
    int page = 1,
    int limit = 20,
  }) async {
    print('Search query: $query, page: $page, limit: $limit');
    final json = await getJson(
      ApiEndpoints.searchProducts,
      query: {'q': query, 'page': page, 'limit': limit},
    );
    print('Search response: $json');
    return ProductPageModel.fromJson(json);
  }

  @override
  Future<List<String>> trendingSearches() async {
    final list = await getList(ApiEndpoints.searchTrending);
    return list
        .map((item) => item.toString().trim())
        .where((item) => item.isNotEmpty)
        .toList();
  }

  @override
  Future<SearchSuggestions> searchSuggestions(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return const SearchSuggestions();
    final json = await getJson(
      ApiEndpoints.searchSuggestions,
      query: {'q': trimmed},
    );
    return SearchSuggestions(
      products: _stringList(json['products']),
      categories: _stringList(json['categories']),
    );
  }

  List<String> _stringList(Object? value) {
    if (value is! List) return const [];
    return value
        .map((item) => item.toString().trim())
        .where((item) => item.isNotEmpty)
        .toList();
  }
}
