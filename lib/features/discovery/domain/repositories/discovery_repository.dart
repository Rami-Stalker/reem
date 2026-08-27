import 'package:reem/core/result/result.dart';
import 'package:reem/core/shared/entities/product.dart';

import 'package:reem/features/discovery/domain/entities/product_page.dart';

abstract interface class DiscoveryRepository {
  Future<Result<ProductPage>> getCollection(
    String collectionKey, {
    int page,
    int limit,
    String? sort,
  });

  Future<Result<ProductPage>> getCategory(
    String category, {
    int page,
    int limit,
    String? sort,
  });

  Future<Result<ProductPage>> getSeller(
    String sellerId, {
    int page,
    int limit,
  });

  Future<Result<ProductPage>> getSimilar(
    String productId, {
    int page,
    int limit,
  });

  Future<Result<ProductPage>> getRecommended({int page, int limit});

  Future<Result<Map<String, List<Product>>>> getHome();
}
