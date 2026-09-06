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

  /// Creates ([listing] == null) or saves the listing. Returns it on success.
  ///
  /// Saving takes the whole listing rather than an id because an edit may
  /// touch both halves of the catalogue — the shared entry and this seller's
  /// offer on it — and the offer's id will not open the catalogue's route.
  Future<ManagedProduct?> submit({
    ManagedProduct? listing,
    required ProductDraft draft,
  }) async {
    state = state.copyWith(isSubmitting: true, clearError: true);
    final result = listing == null
        ? await _create(draft)
        : await _update(listing, draft);
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
