import 'package:reem/core/result/result.dart';

import '../entities/managed_product.dart';
import '../entities/product_draft.dart';
import '../entities/product_status.dart';

abstract interface class SellerProductsRepository {
  Future<Result<ManagedProductPage>> getMyProducts({
    int page,
    int limit,
    ProductStatus? status,
    String? query,
    String? sort,
  });

  Future<Result<ManagedProduct>> getProduct(String id);

  Future<Result<ManagedProduct>> create(ProductDraft draft);

  Future<Result<ManagedProduct>> update(String id, ProductDraft draft);

  Future<Result<void>> delete(String id);

  Future<Result<ManagedProduct>> setStatus(String id, ProductStatus status);

  Future<Result<ManagedProduct>> adjustStock(String id, int delta);
}
