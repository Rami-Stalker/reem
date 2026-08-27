import 'package:reem/core/result/result.dart';
import 'package:reem/core/shared/entities/product.dart';

import 'package:reem/features/catalog/domain/repositories/catalog_repository.dart';

class GetTrendingProductsUseCase {
  const GetTrendingProductsUseCase(this._repository);
  final CatalogRepository _repository;

  Future<Result<List<Product>>> call() => _repository.getTrendingProducts();
}
