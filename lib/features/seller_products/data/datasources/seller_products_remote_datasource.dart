import 'package:reem/features/seller_products/data/models/managed_product_model.dart';
import 'package:reem/features/seller_products/data/models/managed_product_page_model.dart';
import 'package:reem/features/seller_products/domain/entities/product_draft.dart';
import 'package:reem/features/seller_products/domain/entities/product_status.dart';

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
