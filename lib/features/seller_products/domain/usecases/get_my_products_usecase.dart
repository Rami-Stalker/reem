import 'package:reem/core/result/result.dart';

import 'package:reem/features/seller_products/domain/entities/managed_product.dart';
import 'package:reem/features/seller_products/domain/entities/product_status.dart';
import 'package:reem/features/seller_products/domain/repositories/seller_products_repository.dart';

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
