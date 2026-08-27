import 'package:reem/core/result/result.dart';

import 'package:reem/features/cart/domain/entities/cart.dart';
import 'package:reem/features/cart/domain/repositories/cart_repository.dart';

class GetCartUseCase {
  const GetCartUseCase(this._repo);
  final CartRepository _repo;
  Future<Result<Cart>> call() => _repo.getCart();
}

class AddToCartUseCase {
  const AddToCartUseCase(this._repo);
  final CartRepository _repo;
  Future<Result<Cart>> call({
    required String offerId,
    String? offerVariantId,
    int quantity = 1,
  }) =>
      _repo.addItem(
        offerId: offerId,
        offerVariantId: offerVariantId,
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
