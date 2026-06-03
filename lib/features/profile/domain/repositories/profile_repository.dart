import 'package:reem/core/result/result.dart';
import 'package:reem/core/shared/entities/product.dart';
import 'package:reem/core/shared/entities/user.dart';

import '../entities/order_entity.dart';

abstract interface class ProfileRepository {
  Future<Result<User>> getProfile();

  Future<Result<List<Product>>> getFavorites();

  Future<Result<List<OrderEntity>>> getOrders();

  Future<Result<void>> toggleFavorite(String productId);
}
