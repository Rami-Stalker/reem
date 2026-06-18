import 'package:reem/core/network/api_endpoints.dart';
import 'package:reem/core/network/base_remote_datasource.dart';

import '../cart_remote_datasource.dart';
import '../../models/cart_model.dart';

final class CartRemoteDataSourceImpl extends BaseRemoteDataSource
    implements CartRemoteDataSource {
  const CartRemoteDataSourceImpl(super.dio);

  @override
  Future<CartModel> getCart() async {
    final json = await getJson(ApiEndpoints.cart);
    return CartModel.fromJson(json);
  }

  @override
  Future<CartModel> addItem({
    required String productId,
    String? variantId,
    int quantity = 1,
  }) async {
    final json = await postJson(
      ApiEndpoints.cartItems,
      body: {
        'product_id': productId,
        if (variantId != null) 'variant_id': variantId,
        'quantity': quantity,
      },
    );
    return CartModel.fromJson(json);
  }

  @override
  Future<CartModel> updateQuantity({
    required String itemId,
    required int quantity,
  }) async {
    final json = await patchJson(
      ApiEndpoints.cartItemById(itemId),
      body: {'quantity': quantity},
    );
    return CartModel.fromJson(json);
  }

  @override
  Future<CartModel> removeItem(String itemId) async {
    final json = await deleteJson(ApiEndpoints.cartItemById(itemId));
    return CartModel.fromJson(json);
  }

  @override
  Future<CartModel> clear() async {
    final json = await deleteJson(ApiEndpoints.cart);
    return CartModel.fromJson(json);
  }
}
