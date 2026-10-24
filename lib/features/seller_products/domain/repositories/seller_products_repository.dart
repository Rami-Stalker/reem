import 'package:ohara/core/result/result.dart';

import 'package:ohara/features/seller_products/domain/entities/managed_product.dart';
import 'package:ohara/features/seller_products/domain/entities/product_draft.dart';
import 'package:ohara/features/seller_products/domain/entities/product_status.dart';

/// The seller's listings.
///
/// Every mutation but [updateListing] is addressed by the OFFER's id — the
/// thing the seller actually owns. [updateListing] takes the whole listing
/// because editing it may touch both halves of the catalogue, each behind its
/// own route.
abstract interface class SellerProductsRepository {
  Future<Result<ManagedProductPage>> getMyProducts({
    int page,
    int limit,
    ProductStatus? status,
    String? query,
    String? sort,
  });

  /// Listings at or below [threshold] — the dashboard's restock queue.
  Future<Result<List<ManagedProduct>>> lowStock({int threshold});

  Future<Result<ManagedProduct>> getOffer(String offerId);

  Future<Result<ManagedProduct>> create(ProductDraft draft);

  Future<Result<ManagedProduct>> updateListing(
    ManagedProduct listing,
    ProductDraft draft,
  );

  /// Archives the seller's offer. The catalogue entry survives it: order
  /// history points back at the listing for dispute evidence.
  Future<Result<void>> archive(String offerId);

  Future<Result<ManagedProduct>> setStatus(
    String offerId,
    ProductStatus status,
  );

  Future<Result<ManagedProduct>> adjustStock(String offerId, int delta);
}
