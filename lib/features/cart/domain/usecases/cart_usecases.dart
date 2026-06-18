import 'package:reem/core/result/result.dart';

import '../entities/cart.dart';
import '../repositories/cart_repository.dart';

class GetCartUseCase {
  const GetCartUseCase(this._repo);
  final CartRepository _repo;
  Future<Result<Cart>> call() => _repo.getCart();
}

class AddToCartUseCase {
  const AddToCartUseCase(this._repo);
  final CartRepository _repo;
  Future<Result<Cart>> call({
    required String productId,
    String? variantId,
    int quantity = 1,
  }) =>
      _repo.addItem(
        productId: productId,
        variantId: variantId,
        quantity: quantity,
      );
}

class UpdateCartItemUseCase {
  const UpdateCartItemUseCase(this._repo);
  final CartRepository _repo;
  Future<Result<Cart>> call({required String itemId, required int quantity}) =>
      _repo.updateQuantity(itemId: itemId, quantity: quantity);
}

class RemoveCartItemUseCase {
  const RemoveCartItemUseCase(this._repo);
  final CartRepository _repo;
  Future<Result<Cart>> call(String itemId) => _repo.removeItem(itemId);
}

class ClearCartUseCase {
  const ClearCartUseCase(this._repo);
  final CartRepository _repo;
  Future<Result<Cart>> call() => _repo.clear();
}
