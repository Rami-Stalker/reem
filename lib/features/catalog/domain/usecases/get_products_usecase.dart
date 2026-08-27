import 'package:reem/core/result/result.dart';
import 'package:reem/core/shared/entities/product.dart';

import 'package:reem/features/catalog/domain/repositories/catalog_repository.dart';

class GetProductsUseCase {
  const GetProductsUseCase(this._repository);
  final CatalogRepository _repository;

  Future<Result<List<Product>>> call() => _repository.getProducts();
}
