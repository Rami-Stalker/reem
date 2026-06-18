import '../../domain/entities/product_draft.dart';
import '../../domain/entities/product_status.dart';
import '../models/managed_product_model.dart';
import '../models/managed_product_page_model.dart';

abstract interface class SellerProductsRemoteDataSource {
  Future<ManagedProductPageModel> getMyProducts({
    int page,
    int limit,
    ProductStatus? status,
    String? query,
    String? sort,
  });

  Future<ManagedProductModel> getProduct(String id);

  Future<ManagedProductModel> create(ProductDraft draft);

  Future<ManagedProductModel> update(String id, ProductDraft draft);

  Future<void> delete(String id);

  Future<ManagedProductModel> setStatus(String id, ProductStatus status);

  Future<ManagedProductModel> adjustStock(String id, int delta);
}
