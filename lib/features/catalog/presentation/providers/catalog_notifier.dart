import 'package:flutter_riverpod/legacy.dart';
import 'package:reem/core/result/result.dart';

import 'package:reem/features/catalog/domain/usecases/get_product_details_usecase.dart';
import 'package:reem/features/catalog/domain/usecases/get_products_usecase.dart';
import 'package:reem/features/catalog/domain/usecases/get_trending_products_usecase.dart';
import 'package:reem/features/catalog/presentation/providers/catalog_state.dart';

class CatalogNotifier extends StateNotifier<CatalogState> {
  CatalogNotifier({
    required GetProductsUseCase getProductsUseCase,
    required GetTrendingProductsUseCase getTrendingProductsUseCase,
  })  : _getProducts = getProductsUseCase,
        _getTrending = getTrendingProductsUseCase,
        super(const CatalogState());

  final GetProductsUseCase _getProducts;
  final GetTrendingProductsUseCase _getTrending;

  Future<void> load() async {
    state = state.copyWith(isLoading: true, clearError: true);

    final productsResult = await _getProducts();
    final trendingResult = await _getTrending();

    String? error;
    var products = state.products;
    var trending = state.trendingProducts;

    switch (productsResult) {
      case Success(:final data):
        products = data;
      case Error(:final failure):
        error = failure.message;
    }

    switch (trendingResult) {
      case Success(:final data):
        trending = data;
      case Error(:final failure):
        error ??= failure.message;
    }

    state = state.copyWith(
      isLoading: false,
      products: products,
      trendingProducts: trending,
      error: error,
    );
  }
}

class ProductDetailsNotifier extends StateNotifier<ProductDetailsState> {
  ProductDetailsNotifier({
    required GetProductDetailsUseCase getProductDetailsUseCase,
  })  : _getProductDetails = getProductDetailsUseCase,
        super(const ProductDetailsState());

  final GetProductDetailsUseCase _getProductDetails;

  Future<void> load(String productId) async {
    state = state.copyWith(isLoading: true, clearError: true, clearProduct: true);
    final result = await _getProductDetails(productId);
    state = switch (result) {
      Success(:final data) => state.copyWith(isLoading: false, product: data),
      Error(:final failure) =>
        state.copyWith(isLoading: false, error: failure.message),
    };
  }
}
