import 'package:reem/core/result/result.dart';

import 'package:reem/features/discovery/domain/entities/product_page.dart';
import 'package:reem/features/search/domain/entities/search_suggestions.dart';

abstract interface class SearchRepository {
  Future<Result<ProductPage>> searchProducts(
    String query, {
    int page,
    int limit,
  });

  Future<Result<List<String>>> trendingSearches();

  Future<Result<SearchSuggestions>> searchSuggestions(String query);
}
