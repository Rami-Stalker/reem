import 'package:reem/features/seller_products/domain/entities/managed_product.dart';
import 'package:reem/features/seller_products/domain/entities/product_status.dart';

class MyProductsState {
  const MyProductsState({
    this.isLoading = false,
    this.products = const [],
    this.error,
    this.statusFilter,
    this.mutatingId,
  });

  final bool isLoading;
  final List<ManagedProduct> products;
  final String? error;
  final ProductStatus? statusFilter;

  /// Id of the product currently being mutated (delete/status), for per-row spinners.
  final String? mutatingId;

  bool get isEmpty => !isLoading && products.isEmpty;

  MyProductsState copyWith({
    bool? isLoading,
    List<ManagedProduct>? products,
    String? error,
    ProductStatus? statusFilter,
    String? mutatingId,
    bool clearError = false,
    bool clearFilter = false,
    bool clearMutating = false,
  }) {
    return MyProductsState(
      isLoading: isLoading ?? this.isLoading,
      products: products ?? this.products,
      error: clearError ? null : (error ?? this.error),
      statusFilter: clearFilter ? null : (statusFilter ?? this.statusFilter),
      mutatingId: clearMutating ? null : (mutatingId ?? this.mutatingId),
    );
  }
}
