import 'package:reem/core/shared/models/product_model.dart';
import 'package:reem/core/shared/models/user_model.dart';

import '../models/order_model.dart';
import '../models/wishlist_model.dart';

abstract interface class ProfileRemoteDataSource {
  Future<UserModel> getProfile();

  Future<List<ProductModel>> getFavorites();

  Future<WishlistOverviewModel> getWishlistOverview();

  Future<List<OrderModel>> getOrders();

  Future<void> toggleFavorite(String productId);

  Future<void> saveSeller(String sellerId);

  Future<void> savePost(String postId);

  Future<WishlistCollectionModel> createWishlistCollection({
    required String name,
    String? description,
  });

  Future<WishlistShareLinkModel> shareWishlistCollection(String collectionId);
}
