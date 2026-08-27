import 'package:reem/core/result/result.dart';

import 'package:reem/features/seller_products/domain/entities/managed_product.dart';
import 'package:reem/features/seller_products/domain/entities/product_status.dart';
import 'package:reem/features/seller_products/domain/repositories/seller_products_repository.dart';

class SetProductStatusUseCase {
  const SetProductStatusUseCase(this._repository);
  final SellerProductsRepository _repository;

  Future<Result<ManagedProduct>> call(String id, ProductStatus status) =>
      _repository.setStatus(id, status);
}
