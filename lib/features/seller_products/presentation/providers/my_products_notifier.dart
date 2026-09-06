import 'package:flutter_riverpod/legacy.dart';
import 'package:reem/core/result/result.dart';

import 'package:reem/features/seller_products/domain/entities/managed_product.dart';
import 'package:reem/features/seller_products/domain/entities/product_status.dart';
import 'package:reem/features/seller_products/domain/usecases/adjust_stock_usecase.dart';
import 'package:reem/features/seller_products/domain/usecases/archive_listing_usecase.dart';
import 'package:reem/features/seller_products/domain/usecases/get_my_products_usecase.dart';
import 'package:reem/features/seller_products/domain/usecases/set_product_status_usecase.dart';
import 'package:reem/features/seller_products/presentation/providers/my_products_state.dart';

class MyProductsNotifier extends StateNotifier<MyProductsState> {
  MyProductsNotifier({
    required GetMyProductsUseCase getMyProducts,
    required ArchiveListingUseCase archiveListing,
    required SetProductStatusUseCase setProductStatus,
    required AdjustStockUseCase adjustStock,
  })  : _getMyProducts = getMyProducts,
        _archiveListing = archiveListing,
        _setProductStatus = setProductStatus,
        _adjustStock = adjustStock,
        super(const MyProductsState());

  final GetMyProductsUseCase _getMyProducts;
  final ArchiveListingUseCase _archiveListing;
  final SetProductStatusUseCase _setProductStatus;
  final AdjustStockUseCase _adjustStock;

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

  /// Takes a listing off the shop. It is archived, not erased — the row stays
  /// behind the seller's own view so an order placed against it can still be
  /// explained.
  Future<bool> archive(String id) async {
    state = state.copyWith(mutatingId: id, clearError: true);
    final result = await _archiveListing(id);
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

  /// Restocks or draws down a listing by [delta]. The server derives the
  /// published status from the result — a listing that reaches zero goes out of
  /// stock, and one that comes back from zero returns to the shop — so the row
  /// it answers with is the one worth trusting.
  Future<bool> adjustStock(String id, int delta) async {
    if (delta == 0) return true;
    state = state.copyWith(mutatingId: id, clearError: true);
    final result = await _adjustStock(id, delta);
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

  /// Folds a freshly saved listing back into the list, so returning from the
  /// form does not need a round trip to show the new figures.
  void upsert(ManagedProduct listing) {
    final known = state.products.any((p) => p.id == listing.id);
    state = state.copyWith(
      products: known ? _replace(listing) : [listing, ...state.products],
    );
  }

  List<ManagedProduct> _replace(ManagedProduct updated) =>
      state.products.map((p) => p.id == updated.id ? updated : p).toList();
}
