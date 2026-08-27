import 'package:reem/features/cart/data/models/cart_model.dart';

abstract interface class CartRemoteDataSource {
  Future<CartModel> getCart();

  Future<CartModel> addItem({
    required String offerId,
    String? offerVariantId,
    int quantity,
  });

  Future<CartModel> updateQuantity({
    required String itemId,
    required int quantity,
  });

  Future<CartModel> removeItem(String itemId);

  Future<CartModel> clear();
}
