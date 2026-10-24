import 'package:ohara/core/result/result.dart';

import 'package:ohara/features/seller_products/domain/repositories/seller_products_repository.dart';

/// Takes the seller's listing off the shop. The catalogue entry stays: past
/// orders point back at it, and a dispute needs the page they were bought from.
class ArchiveListingUseCase {
  const ArchiveListingUseCase(this._repository);
  final SellerProductsRepository _repository;

  Future<Result<void>> call(String offerId) => _repository.archive(offerId);
}
