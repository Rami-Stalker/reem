import 'package:reem/core/result/result.dart';

import '../entities/managed_product.dart';
import '../repositories/seller_products_repository.dart';

class AdjustStockUseCase {
  const AdjustStockUseCase(this._repository);
  final SellerProductsRepository _repository;

  Future<Result<ManagedProduct>> call(String id, int delta) =>
      _repository.adjustStock(id, delta);
}
