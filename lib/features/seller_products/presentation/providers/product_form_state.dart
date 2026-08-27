import 'package:reem/features/seller_products/domain/entities/managed_product.dart';

class ProductFormState {
  const ProductFormState({
    this.isSubmitting = false,
    this.error,
    this.saved,
  });

  final bool isSubmitting;
  final String? error;
  final ManagedProduct? saved;

  ProductFormState copyWith({
    bool? isSubmitting,
    String? error,
    ManagedProduct? saved,
    bool clearError = false,
  }) {
    return ProductFormState(
      isSubmitting: isSubmitting ?? this.isSubmitting,
      error: clearError ? null : (error ?? this.error),
      saved: saved ?? this.saved,
    );
  }
}
