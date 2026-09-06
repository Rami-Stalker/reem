import 'package:reem/core/result/result.dart';

import 'package:reem/features/seller_products/domain/entities/managed_product.dart';
import 'package:reem/features/seller_products/domain/entities/product_draft.dart';
import 'package:reem/features/seller_products/domain/repositories/seller_products_repository.dart';

/// Saves an edit to a listing. It takes the listing rather than an id because
/// a product's identity and a seller's terms live behind different routes, and
/// the offer's id will not open the catalogue's.
class UpdateProductUseCase {
  const UpdateProductUseCase(this._repository);
  final SellerProductsRepository _repository;

  Future<Result<ManagedProduct>> call(
    ManagedProduct listing,
    ProductDraft draft,
  ) =>
      _repository.updateListing(listing, draft);
}
