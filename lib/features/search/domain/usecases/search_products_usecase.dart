import 'package:reem/core/result/result.dart';

import 'package:reem/features/discovery/domain/entities/product_page.dart';
import 'package:reem/features/search/domain/repositories/search_repository.dart';

class SearchProductsUseCase {
  const SearchProductsUseCase(this._repo);
  final SearchRepository _repo;

  Future<Result<ProductPage>> call(
    String query, {
    int page = 1,
    int limit = 20,
  }) =>
      _repo.searchProducts(query, page: page, limit: limit);
}
