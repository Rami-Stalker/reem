import 'package:ohara/core/domain/pagination/paginated_data.dart';
import 'package:ohara/core/network/api_endpoints.dart';
import 'package:ohara/core/network/base_remote_datasource.dart';
import 'package:ohara/core/shared/entities/post.dart';
import 'package:ohara/core/shared/entities/user.dart';
import 'package:ohara/core/shared/models/post_model.dart';
import 'package:ohara/core/shared/models/product_model.dart';
import 'package:ohara/core/shared/models/user_model.dart';
import 'package:ohara/features/discovery/data/models/product_page_model.dart';
import 'package:ohara/features/search/data/datasources/search_remote_datasource.dart';
import 'package:ohara/features/search/domain/entities/search_suggestions.dart';
import 'package:ohara/features/search/domain/entities/unified_search.dart';

final class SearchRemoteDataSourceImpl extends BaseRemoteDataSource
    implements SearchRemoteDataSource {
  const SearchRemoteDataSourceImpl(super.dio);

  @override
  Future<ProductPageModel> searchProducts(
    String query, {
    int page = 1,
    int limit = 20,
  }) async {
    // No logging here. These two lines used to print the query and the whole
    // response to the device log, where on some Android builds another app
    // can read them — a woman's search history is not ours to leave lying
    // about. `TelemetryInterceptor` records the request's shape, redacted.
    final json = await getJson(
      ApiEndpoints.searchProducts,
      query: {'q': query, 'page': page, 'limit': limit},
    );
    return ProductPageModel.fromJson(json);
  }

  @override
  Future<UnifiedSearch> searchAll(String query) async {
    final json = await getJson(ApiEndpoints.search, query: {'q': query});
    List<Map<String, dynamic>> rows(String key) =>
        (json[key] as List? ?? const [])
            .whereType<Map<String, dynamic>>()
            .toList(growable: false);
    return UnifiedSearch(
      products: rows('products').map(ProductModel.fromJson).toList(),
      boutiques: rows('sellers').map(UserModel.fromJson).toList(),
      shoppers: rows('customers').map(UserModel.fromJson).toList(),
      posts: rows('posts').map(PostModel.fromJson).toList(),
    );
  }

  @override
  Future<PaginatedData<User>> searchBoutiques(
    String query, {
    int page = 1,
    int limit = 20,
  }) => getPaginated<User>(
    ApiEndpoints.searchSellers,
    query: {'q': query, 'page': page, 'limit': limit},
    itemFromJson: UserModel.fromJson,
  );

  @override
  Future<PaginatedData<User>> searchShoppers(
    String query, {
    int page = 1,
    int limit = 20,
  }) => getPaginated<User>(
    ApiEndpoints.searchUsers,
    query: {'q': query, 'page': page, 'limit': limit},
    itemFromJson: UserModel.fromJson,
  );

  @override
  Future<PaginatedData<Post>> searchPosts(
    String query, {
    int page = 1,
    int limit = 20,
  }) => getPaginated<Post>(
    ApiEndpoints.searchPosts,
    query: {'q': query, 'page': page, 'limit': limit},
    itemFromJson: PostModel.fromJson,
  );

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
