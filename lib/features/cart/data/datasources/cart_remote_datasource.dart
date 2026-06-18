import '../models/cart_model.dart';

abstract interface class CartRemoteDataSource {
  Future<CartModel> getCart();

  Future<CartModel> addItem({
    required String productId,
    String? variantId,
    int quantity,
  });

  Future<CartModel> updateQuantity({
    required String itemId,
    required int quantity,
  });

  Future<CartModel> removeItem(String itemId);

  Future<CartModel> clear();
}
