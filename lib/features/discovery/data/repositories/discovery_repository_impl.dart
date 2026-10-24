import 'package:ohara/core/base/repository_handler.dart';
import 'package:ohara/core/result/result.dart';
import 'package:ohara/core/shared/entities/product.dart';
import 'package:ohara/features/discovery/data/datasources/discovery_remote_datasource.dart';
import 'package:ohara/features/discovery/domain/entities/product_page.dart';
import 'package:ohara/features/discovery/domain/repositories/discovery_repository.dart';

class DiscoveryRepositoryImpl
    with RepositoryHandler
    implements DiscoveryRepository {
  const DiscoveryRepositoryImpl(this.remote);

  final DiscoveryRemoteDataSource remote;

  @override
  Future<Result<ProductPage>> getCollection(
    String collectionKey, {
    int page = 1,
    int limit = 20,
    String? sort,
  }) =>
      guard(() => remote.getCollection(collectionKey,
          page: page, limit: limit, sort: sort));

  @override
  Future<Result<ProductPage>> getCategory(
    String category, {
    int page = 1,
    int limit = 20,
    String? sort,
  }) =>
      guard(() =>
          remote.getCategory(category, page: page, limit: limit, sort: sort));

  @override
  Future<Result<ProductPage>> getSeller(String sellerId,
          {int page = 1, int limit = 20}) =>
      guard(() => remote.getSeller(sellerId, page: page, limit: limit));

  @override
  Future<Result<ProductPage>> getSimilar(String productId,
          {int page = 1, int limit = 20}) =>
      guard(() => remote.getSimilar(productId, page: page, limit: limit));

  @override
  Future<Result<ProductPage>> getRecommended({int page = 1, int limit = 20}) =>
      guard(() => remote.getRecommended(page: page, limit: limit));

  @override
  Future<Result<void>> dismissRecommendation(String productId) =>
      guard(() => remote.dismissRecommendation(productId));

  @override
  Future<Result<void>> restoreRecommendation(String productId) =>
      guard(() => remote.restoreRecommendation(productId));

  @override
  Future<Result<Map<String, List<Product>>>> getHome() =>
      guard<Map<String, List<Product>>>(() async {
        final raw = await remote.getHome();
        return raw.map((key, value) => MapEntry(key, value.cast<Product>()));
      });
}
