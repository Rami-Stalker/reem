import 'package:reem/core/network/api_endpoints.dart';
import 'package:reem/core/network/base_remote_datasource.dart';
import 'package:reem/core/shared/models/product_model.dart';

import '../../models/product_page_model.dart';
import '../discovery_remote_datasource.dart';

final class DiscoveryRemoteDataSourceImpl extends BaseRemoteDataSource
    implements DiscoveryRemoteDataSource {
  const DiscoveryRemoteDataSourceImpl(super.dio);

  Map<String, dynamic> _query(int page, int limit, String? sort) => {
        'page': page,
        'limit': limit,
        if (sort != null) 'sort': sort,
      };

  @override
  Future<ProductPageModel> getCollection(String key,
      {int page = 1, int limit = 20, String? sort}) async {
    final json = await getJson(
      ApiEndpoints.discoveryCollection(key),
      query: _query(page, limit, sort),
    );
    return ProductPageModel.fromJson(json);
  }

  @override
  Future<ProductPageModel> getCategory(String category,
      {int page = 1, int limit = 20, String? sort}) async {
    final json = await getJson(
      ApiEndpoints.discoveryCategory(category),
      query: _query(page, limit, sort),
    );
    return ProductPageModel.fromJson(json);
  }

  @override
  Future<ProductPageModel> getSeller(String sellerId,
      {int page = 1, int limit = 20}) async {
    final json = await getJson(
      ApiEndpoints.discoverySeller(sellerId),
      query: _query(page, limit, null),
    );
    return ProductPageModel.fromJson(json);
  }

  @override
  Future<ProductPageModel> getSimilar(String productId,
      {int page = 1, int limit = 20}) async {
    final json = await getJson(
      ApiEndpoints.discoverySimilar(productId),
      query: _query(page, limit, null),
    );
    return ProductPageModel.fromJson(json);
  }

  @override
  Future<ProductPageModel> getRecommended({int page = 1, int limit = 20}) async {
    final json = await getJson(
      ApiEndpoints.discoveryRecommended,
      query: _query(page, limit, null),
    );
    return ProductPageModel.fromJson(json);
  }

  @override
  Future<Map<String, List<ProductModel>>> getHome() async {
    final json = await getJson(ApiEndpoints.discoveryHome);
    return json.map(
      (key, value) => MapEntry(
        key,
        (value as List? ?? [])
            .map((e) => ProductModel.fromJson(e as Map<String, dynamic>))
            .toList(),
      ),
    );
  }
}
