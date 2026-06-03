import 'package:reem/core/result/result.dart';
import 'package:reem/core/shared/entities/product.dart';

abstract interface class CatalogRepository {
  Future<Result<List<Product>>> getTrendingProducts();

  Future<Result<Product>> getProductById(String id);

  Future<Result<List<Product>>> getProducts();
}
