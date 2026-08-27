import 'package:reem/features/discovery/data/models/product_page_model.dart';
import 'package:reem/features/search/domain/entities/search_suggestions.dart';

abstract interface class SearchRemoteDataSource {
  Future<ProductPageModel> searchProducts(String query, {int page, int limit});

  Future<List<String>> trendingSearches();

  Future<SearchSuggestions> searchSuggestions(String query);
}
