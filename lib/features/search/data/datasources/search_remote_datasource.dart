import 'package:ohara/core/domain/pagination/paginated_data.dart';
import 'package:ohara/core/shared/entities/post.dart';
import 'package:ohara/core/shared/entities/user.dart';
import 'package:ohara/features/discovery/data/models/product_page_model.dart';
import 'package:ohara/features/search/domain/entities/search_suggestions.dart';
import 'package:ohara/features/search/domain/entities/unified_search.dart';

abstract interface class SearchRemoteDataSource {
  Future<ProductPageModel> searchProducts(String query, {int page, int limit});

  /// Top hits across products, boutiques, shoppers and posts.
  Future<UnifiedSearch> searchAll(String query);

  Future<PaginatedData<User>> searchBoutiques(
    String query, {
    int page,
    int limit,
  });

  Future<PaginatedData<User>> searchShoppers(
    String query, {
    int page,
    int limit,
  });

  Future<PaginatedData<Post>> searchPosts(String query, {int page, int limit});

  Future<List<String>> trendingSearches();

  Future<SearchSuggestions> searchSuggestions(String query);
}
