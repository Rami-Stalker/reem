import 'package:reem/core/result/result.dart';

import 'package:reem/features/seller_products/domain/entities/managed_product.dart';
import 'package:reem/features/seller_products/domain/repositories/seller_products_repository.dart';

class AdjustStockUseCase {
  const AdjustStockUseCase(this._repository);
  final SellerProductsRepository _repository;

  Future<Result<ManagedProduct>> call(String id, int delta) =>
      _repository.adjustStock(id, delta);
}
