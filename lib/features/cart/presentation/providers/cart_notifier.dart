import 'package:flutter_riverpod/legacy.dart';
import 'package:reem/core/result/result.dart';

import '../../domain/entities/cart.dart';
import '../../domain/usecases/cart_usecases.dart';
import 'cart_state.dart';

class CartNotifier extends StateNotifier<CartState> {
  CartNotifier({
    required GetCartUseCase getCart,
    required AddToCartUseCase addToCart,
    required UpdateCartItemUseCase updateItem,
    required RemoveCartItemUseCase removeItem,
    required ClearCartUseCase clearCart,
  })  : _getCart = getCart,
        _addToCart = addToCart,
        _updateItem = updateItem,
        _removeItem = removeItem,
        _clearCart = clearCart,
        super(const CartState());

  final GetCartUseCase _getCart;
  final AddToCartUseCase _addToCart;
  final UpdateCartItemUseCase _updateItem;
  final RemoveCartItemUseCase _removeItem;
  final ClearCartUseCase _clearCart;

  Future<void> load() async {
    state = state.copyWith(isLoading: true, clearError: true);
    _apply(await _getCart(), loadingDone: true);
  }

  Future<bool> add({
    required String productId,
    String? variantId,
    int quantity = 1,
  }) async {
    state = state.copyWith(clearError: true);
    final result = await _addToCart(
      productId: productId,
      variantId: variantId,
      quantity: quantity,
    );
    return _apply(result);
  }

  Future<void> setQuantity(CartLine line, int quantity) async {
    if (quantity < 1) return removeLine(line);
    state = state.copyWith(mutatingItemId: line.id, clearError: true);
    _apply(await _updateItem(itemId: line.id, quantity: quantity),
        clearMutating: true);
  }

  Future<void> increment(CartLine line) => setQuantity(line, line.quantity + 1);
  Future<void> decrement(CartLine line) => setQuantity(line, line.quantity - 1);

  Future<void> removeLine(CartLine line) async {
    state = state.copyWith(mutatingItemId: line.id, clearError: true);
    _apply(await _removeItem(line.id), clearMutating: true);
  }

  Future<void> clear() async {
    _apply(await _clearCart());
  }

  Future<void> refresh() => load();

  bool _apply(
    Result<Cart> result, {
    bool loadingDone = false,
    bool clearMutating = false,
  }) {
    switch (result) {
      case Success(:final data):
        state = state.copyWith(
          isLoading: false,
          cart: data,
          clearMutating: clearMutating,
        );
        return true;
      case Error(:final failure):
        state = state.copyWith(
          isLoading: loadingDone ? false : state.isLoading,
          error: failure.message,
          clearMutating: clearMutating,
        );
        return false;
    }
  }
}
