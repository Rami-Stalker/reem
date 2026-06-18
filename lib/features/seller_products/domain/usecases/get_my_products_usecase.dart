import 'package:reem/core/result/result.dart';

import '../entities/managed_product.dart';
import '../entities/product_status.dart';
import '../repositories/seller_products_repository.dart';

class GetMyProductsUseCase {
  const GetMyProductsUseCase(this._repository);
  final SellerProductsRepository _repository;

  Future<Result<ManagedProductPage>> call({
    int page = 1,
    int limit = 20,
    ProductStatus? status,
    String? query,
    String? sort,
  }) =>
      _repository.getMyProducts(
        page: page,
        limit: limit,
        status: status,
        query: query,
        sort: sort,
      );
}
