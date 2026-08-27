import 'package:reem/core/result/result.dart';

import 'package:reem/features/seller_products/domain/entities/managed_product.dart';
import 'package:reem/features/seller_products/domain/entities/product_draft.dart';
import 'package:reem/features/seller_products/domain/repositories/seller_products_repository.dart';

class UpdateProductUseCase {
  const UpdateProductUseCase(this._repository);
  final SellerProductsRepository _repository;

  Future<Result<ManagedProduct>> call(String id, ProductDraft draft) =>
      _repository.update(id, draft);
}
