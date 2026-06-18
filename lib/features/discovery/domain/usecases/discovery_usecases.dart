import 'package:reem/core/result/result.dart';
import 'package:reem/core/shared/entities/product.dart';

import '../entities/product_page.dart';
import '../repositories/discovery_repository.dart';

/// Dedicated use case for a static collection (trending, featured, …).
class GetCollectionUseCase {
  const GetCollectionUseCase(this._repo);
  final DiscoveryRepository _repo;
  Future<Result<ProductPage>> call(
    String collectionKey, {
    int page = 1,
    int limit = 20,
    String? sort,
  }) =>
      _repo.getCollection(collectionKey, page: page, limit: limit, sort: sort);
}

class GetCategoryProductsUseCase {
  const GetCategoryProductsUseCase(this._repo);
  final DiscoveryRepository _repo;
  Future<Result<ProductPage>> call(
    String category, {
    int page = 1,
    int limit = 20,
    String? sort,
  }) =>
      _repo.getCategory(category, page: page, limit: limit, sort: sort);
}

class GetSellerProductsUseCase {
  const GetSellerProductsUseCase(this._repo);
  final DiscoveryRepository _repo;
  Future<Result<ProductPage>> call(String sellerId,
          {int page = 1, int limit = 20}) =>
      _repo.getSeller(sellerId, page: page, limit: limit);
}

class GetSimilarProductsUseCase {
  const GetSimilarProductsUseCase(this._repo);
  final DiscoveryRepository _repo;
  Future<Result<ProductPage>> call(String productId,
          {int page = 1, int limit = 20}) =>
      _repo.getSimilar(productId, page: page, limit: limit);
}

class GetRecommendedUseCase {
  const GetRecommendedUseCase(this._repo);
  final DiscoveryRepository _repo;
  Future<Result<ProductPage>> call({int page = 1, int limit = 20}) =>
      _repo.getRecommended(page: page, limit: limit);
}

class GetDiscoveryHomeUseCase {
  const GetDiscoveryHomeUseCase(this._repo);
  final DiscoveryRepository _repo;
  Future<Result<Map<String, List<Product>>>> call() => _repo.getHome();
}
