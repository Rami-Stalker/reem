import 'package:reem/core/result/result.dart';

import 'package:reem/features/seller_products/domain/entities/managed_product.dart';
import 'package:reem/features/seller_products/domain/repositories/seller_products_repository.dart';

/// The restock queue: listings at or below a threshold, soonest to run out
/// first.
class GetLowStockUseCase {
  const GetLowStockUseCase(this._repository);
  final SellerProductsRepository _repository;

  Future<Result<List<ManagedProduct>>> call({int threshold = 5}) =>
      _repository.lowStock(threshold: threshold);
}
