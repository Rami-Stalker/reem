import 'package:reem/core/shared/models/product_model.dart';
import 'package:reem/core/shared/models/user_model.dart';

import '../models/order_model.dart';

abstract interface class ProfileRemoteDataSource {
  Future<UserModel> getProfile();

  Future<List<ProductModel>> getFavorites();

  Future<List<OrderModel>> getOrders();

  Future<void> toggleFavorite(String productId);
}
