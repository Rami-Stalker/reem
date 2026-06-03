import 'package:reem/core/shared/models/product_model.dart';

abstract interface class CatalogRemoteDataSource {
  Future<List<ProductModel>> getTrendingProducts();

  Future<ProductModel> getProductById(String id);

  Future<List<ProductModel>> getProducts();
}
