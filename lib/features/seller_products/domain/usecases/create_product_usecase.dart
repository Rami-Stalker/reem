import 'package:ohara/core/result/result.dart';

import 'package:ohara/features/seller_products/domain/entities/managed_product.dart';
import 'package:ohara/features/seller_products/domain/entities/product_draft.dart';
import 'package:ohara/features/seller_products/domain/repositories/seller_products_repository.dart';

class CreateProductUseCase {
  const CreateProductUseCase(this._repository);
  final SellerProductsRepository _repository;

  Future<Result<ManagedProduct>> call(ProductDraft draft) =>
      _repository.create(draft);
}
