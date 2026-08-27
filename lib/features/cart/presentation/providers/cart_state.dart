import 'package:reem/features/cart/domain/entities/cart.dart';

class CartState {
  const CartState({
    this.isLoading = false,
    this.cart = const Cart(),
    this.error,
    this.mutatingItemId,
  });

  final bool isLoading;
  final Cart cart;
  final String? error;
  final String? mutatingItemId;

  bool get isEmpty => !isLoading && cart.isEmpty;

  CartState copyWith({
    bool? isLoading,
    Cart? cart,
    String? error,
    String? mutatingItemId,
    bool clearError = false,
    bool clearMutating = false,
  }) {
    return CartState(
      isLoading: isLoading ?? this.isLoading,
      cart: cart ?? this.cart,
      error: clearError ? null : (error ?? this.error),
      mutatingItemId: clearMutating ? null : (mutatingItemId ?? this.mutatingItemId),
    );
  }
}
