import 'package:ohara/core/shared/entities/product.dart';

class CatalogState {
  const CatalogState({
    this.products = const [],
    this.trendingProducts = const [],
    this.isLoading = false,
    this.error,
  });

  final List<Product> products;
  final List<Product> trendingProducts;
  final bool isLoading;
  final String? error;

  CatalogState copyWith({
    List<Product>? products,
    List<Product>? trendingProducts,
    bool? isLoading,
    String? error,
    bool clearError = false,
  }) {
    return CatalogState(
      products: products ?? this.products,
      trendingProducts: trendingProducts ?? this.trendingProducts,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class ProductDetailsState {
  const ProductDetailsState({
    this.product,
    this.isLoading = false,
    this.error,
  });

  final Product? product;
  final bool isLoading;
  final String? error;

  ProductDetailsState copyWith({
    Product? product,
    bool? isLoading,
    String? error,
    bool clearProduct = false,
    bool clearError = false,
  }) {
    return ProductDetailsState(
      product: clearProduct ? null : (product ?? this.product),
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
    );
  }
}
