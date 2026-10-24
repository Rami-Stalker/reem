import 'package:ohara/core/result/result.dart';
import 'package:ohara/core/shared/entities/product.dart';

import 'package:ohara/features/catalog/domain/repositories/catalog_repository.dart';

class GetTrendingProductsUseCase {
  const GetTrendingProductsUseCase(this._repository);
  final CatalogRepository _repository;

  Future<Result<List<Product>>> call() => _repository.getTrendingProducts();
}
