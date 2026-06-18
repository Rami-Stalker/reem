import 'package:reem/core/result/result.dart';

import '../entities/managed_product.dart';
import '../repositories/seller_products_repository.dart';

class GetManagedProductUseCase {
  const GetManagedProductUseCase(this._repository);
  final SellerProductsRepository _repository;

  Future<Result<ManagedProduct>> call(String id) =>
      _repository.getProduct(id);
}
