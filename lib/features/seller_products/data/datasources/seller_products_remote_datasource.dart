import 'package:ohara/features/seller_products/data/models/managed_product_model.dart';
import 'package:ohara/features/seller_products/data/models/managed_product_page_model.dart';
import 'package:ohara/features/seller_products/domain/entities/product_draft.dart';
import 'package:ohara/features/seller_products/domain/entities/product_status.dart';

/// Every mutation is addressed by the OFFER's id, except [updateProduct],
/// which edits the shared catalogue entry and therefore takes the product's.
abstract interface class SellerProductsRemoteDataSource {
  Future<ManagedProductPageModel> getMyProducts({
    int page,
    int limit,
    ProductStatus? status,
    String? query,
    String? sort,
  });

  Future<List<ManagedProductModel>> lowStock({int threshold});

  Future<ManagedProductModel> getOffer(String offerId);

  Future<ManagedProductModel> create(ProductDraft draft);

  /// Edits the seller's terms: price, stock, fulfilment, published status.
  Future<ManagedProductModel> updateOffer(String offerId, ProductDraft draft);

  /// Edits the shared entry: title, description, category, gallery. Permitted
  /// only while she is the sole seller listing it.
  Future<void> updateProduct(String productId, ProductDraft draft);

  Future<void> archive(String offerId);

  Future<ManagedProductModel> setStatus(String offerId, ProductStatus status);

  Future<ManagedProductModel> adjustStock(String offerId, int delta);
}
