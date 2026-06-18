import 'package:reem/core/result/result.dart';

import '../entities/managed_product.dart';
import '../entities/product_draft.dart';
import '../repositories/seller_products_repository.dart';

class CreateProductUseCase {
  const CreateProductUseCase(this._repository);
  final SellerProductsRepository _repository;

  Future<Result<ManagedProduct>> call(ProductDraft draft) =>
      _repository.create(draft);
}
