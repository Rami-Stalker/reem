import 'package:reem/core/base/repository_handler.dart';
import 'package:reem/core/result/result.dart';
import 'package:reem/features/cart/data/datasources/cart_remote_datasource.dart';
import 'package:reem/features/cart/domain/entities/cart.dart';
import 'package:reem/features/cart/domain/repositories/cart_repository.dart';

class CartRepositoryImpl with RepositoryHandler implements CartRepository {
  const CartRepositoryImpl(this.remote);

  final CartRemoteDataSource remote;

  @override
  Future<Result<Cart>> getCart() => guard(() => remote.getCart());

  @override
  Future<Result<Cart>> addItem({
    required String offerId,
    String? offerVariantId,
    int quantity = 1,
  }) =>
      guard(() => remote.addItem(
            offerId: offerId,
            offerVariantId: offerVariantId,
            quantity: quantity,
          ));

  @override
  Future<Result<Cart>> updateQuantity({
    required String itemId,
    required int quantity,
  }) =>
      guard(() => remote.updateQuantity(itemId: itemId, quantity: quantity));

  @override
  Future<Result<Cart>> removeItem(String itemId) =>
      guard(() => remote.removeItem(itemId));

  @override
  Future<Result<Cart>> clear() => guard(() => remote.clear());
}
