import 'package:reem/core/result/result.dart';

import '../repositories/seller_products_repository.dart';

class DeleteProductUseCase {
  const DeleteProductUseCase(this._repository);
  final SellerProductsRepository _repository;

  Future<Result<void>> call(String id) => _repository.delete(id);
}
