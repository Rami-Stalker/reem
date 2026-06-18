import 'package:reem/core/result/result.dart';

import '../entities/managed_product.dart';
import '../entities/product_status.dart';
import '../repositories/seller_products_repository.dart';

class SetProductStatusUseCase {
  const SetProductStatusUseCase(this._repository);
  final SellerProductsRepository _repository;

  Future<Result<ManagedProduct>> call(String id, ProductStatus status) =>
      _repository.setStatus(id, status);
}
