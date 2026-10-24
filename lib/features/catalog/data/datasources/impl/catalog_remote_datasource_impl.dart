import 'package:ohara/core/network/api_endpoints.dart';
import 'package:ohara/core/network/base_remote_datasource.dart';
import 'package:ohara/core/shared/models/product_model.dart';
import 'package:ohara/features/catalog/data/datasources/catalog_remote_datasource.dart';

final class CatalogRemoteDataSourceImpl extends BaseRemoteDataSource
    implements CatalogRemoteDataSource {
  const CatalogRemoteDataSourceImpl(super.dio);

  @override
  Future<List<ProductModel>> getTrendingProducts() async {
    final list = await getList(ApiEndpoints.productsTrending);
    return _parseProducts(list);
  }

  @override
  Future<ProductModel> getProductById(String id) async {
    final json = await getJson(ApiEndpoints.productById(id));
    final productJson = json['product'] is Map<String, dynamic>
        ? json['product'] as Map<String, dynamic>
        : json;
    return ProductModel.fromJson(productJson);
  }

  @override
  Future<List<ProductModel>> getProducts() async {
    final list = await getList(ApiEndpoints.products);
    return _parseProducts(list);
  }

  List<ProductModel> _parseProducts(List<dynamic> list) {
    return list
        .whereType<Map>()
        .map((e) => ProductModel.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }
}
