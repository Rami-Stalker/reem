import 'package:reem/core/result/result.dart';

import '../entities/cart.dart';

abstract interface class CartRepository {
  Future<Result<Cart>> getCart();

  Future<Result<Cart>> addItem({
    required String offerId,
    String? offerVariantId,
    int quantity,
  });

  Future<Result<Cart>> updateQuantity({
    required String itemId,
    required int quantity,
  });

  Future<Result<Cart>> removeItem(String itemId);

  Future<Result<Cart>> clear();
}
