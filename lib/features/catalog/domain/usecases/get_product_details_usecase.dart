import 'package:reem/core/result/result.dart';
import 'package:reem/core/shared/entities/product.dart';

import 'package:reem/features/catalog/domain/repositories/catalog_repository.dart';

class GetProductDetailsUseCase {
  const GetProductDetailsUseCase(this._repository);
  final CatalogRepository _repository;

  Future<Result<Product>> call(String id) => _repository.getProductById(id);
}
