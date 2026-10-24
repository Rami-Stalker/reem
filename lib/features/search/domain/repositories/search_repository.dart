import 'package:ohara/core/domain/pagination/paginated_data.dart';
import 'package:ohara/core/result/result.dart';
import 'package:ohara/core/shared/entities/post.dart';
import 'package:ohara/core/shared/entities/user.dart';
import 'package:ohara/features/discovery/domain/entities/product_page.dart';
import 'package:ohara/features/search/domain/entities/search_suggestions.dart';
import 'package:ohara/features/search/domain/entities/unified_search.dart';

abstract interface class SearchRepository {
  Future<Result<ProductPage>> searchProducts(
    String query, {
    int page,
    int limit,
  });

  Future<Result<UnifiedSearch>> searchAll(String query);

  Future<Result<PaginatedData<User>>> searchBoutiques(
    String query, {
    int page,
    int limit,
  });

  Future<Result<PaginatedData<User>>> searchShoppers(
    String query, {
    int page,
    int limit,
  });

  Future<Result<PaginatedData<Post>>> searchPosts(
    String query, {
    int page,
    int limit,
  });

  Future<Result<List<String>>> trendingSearches();

  Future<Result<SearchSuggestions>> searchSuggestions(String query);
}
