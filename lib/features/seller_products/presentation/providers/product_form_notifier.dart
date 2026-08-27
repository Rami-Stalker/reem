import 'package:flutter_riverpod/legacy.dart';
import 'package:reem/core/result/result.dart';

import 'package:reem/features/seller_products/domain/entities/managed_product.dart';
import 'package:reem/features/seller_products/domain/entities/product_draft.dart';
import 'package:reem/features/seller_products/domain/usecases/create_product_usecase.dart';
import 'package:reem/features/seller_products/domain/usecases/update_product_usecase.dart';
import 'package:reem/features/seller_products/presentation/providers/product_form_state.dart';

class ProductFormNotifier extends StateNotifier<ProductFormState> {
  ProductFormNotifier({
    required CreateProductUseCase createProduct,
    required UpdateProductUseCase updateProduct,
  })  : _create = createProduct,
        _update = updateProduct,
        super(const ProductFormState());

  final CreateProductUseCase _create;
  final UpdateProductUseCase _update;

  /// Creates (id == null) or updates the product. Returns it on success.
  Future<ManagedProduct?> submit({
    String? id,
    required ProductDraft draft,
  }) async {
    state = state.copyWith(isSubmitting: true, clearError: true);
    final result = id == null ? await _create(draft) : await _update(id, draft);
    return switch (result) {
      Success(:final data) => () {
          state = state.copyWith(isSubmitting: false, saved: data);
          return data;
        }(),
      Error(:final failure) => () {
          state = state.copyWith(isSubmitting: false, error: failure.message);
          return null;
        }(),
    };
  }
}
