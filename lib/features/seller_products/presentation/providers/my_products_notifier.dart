import 'package:flutter_riverpod/legacy.dart';
import 'package:reem/core/result/result.dart';

import '../../domain/entities/managed_product.dart';
import '../../domain/entities/product_status.dart';
import '../../domain/usecases/delete_product_usecase.dart';
import '../../domain/usecases/get_my_products_usecase.dart';
import '../../domain/usecases/set_product_status_usecase.dart';
import 'my_products_state.dart';

class MyProductsNotifier extends StateNotifier<MyProductsState> {
  MyProductsNotifier({
    required GetMyProductsUseCase getMyProducts,
    required DeleteProductUseCase deleteProduct,
    required SetProductStatusUseCase setProductStatus,
  })  : _getMyProducts = getMyProducts,
        _deleteProduct = deleteProduct,
        _setProductStatus = setProductStatus,
        super(const MyProductsState());

  final GetMyProductsUseCase _getMyProducts;
  final DeleteProductUseCase _deleteProduct;
  final SetProductStatusUseCase _setProductStatus;

  Future<void> load() async {
    state = state.copyWith(isLoading: true, clearError: true);
    final result = await _getMyProducts(status: state.statusFilter);
    state = switch (result) {
      Success(:final data) =>
        state.copyWith(isLoading: false, products: data.items),
      Error(:final failure) =>
        state.copyWith(isLoading: false, error: failure.message),
    };
  }

  Future<void> refresh() => load();

  Future<void> setFilter(ProductStatus? status) async {
    state = status == null
        ? state.copyWith(clearFilter: true)
        : state.copyWith(statusFilter: status);
    await load();
  }

  Future<bool> delete(String id) async {
    state = state.copyWith(mutatingId: id, clearError: true);
    final result = await _deleteProduct(id);
    return switch (result) {
      Success() => () {
          state = state.copyWith(
            products: state.products.where((p) => p.id != id).toList(),
            clearMutating: true,
          );
          return true;
        }(),
      Error(:final failure) => () {
          state = state.copyWith(error: failure.message, clearMutating: true);
          return false;
        }(),
    };
  }

  Future<bool> changeStatus(String id, ProductStatus status) async {
    state = state.copyWith(mutatingId: id, clearError: true);
    final result = await _setProductStatus(id, status);
    return switch (result) {
      Success(:final data) => () {
          state = state.copyWith(products: _replace(data), clearMutating: true);
          return true;
        }(),
      Error(:final failure) => () {
          state = state.copyWith(error: failure.message, clearMutating: true);
          return false;
        }(),
    };
  }

  List<ManagedProduct> _replace(ManagedProduct updated) =>
      state.products.map((p) => p.id == updated.id ? updated : p).toList();
}
