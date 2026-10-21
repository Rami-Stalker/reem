import 'package:reem/core/shared/models/product_model.dart';
import 'package:reem/core/shared/models/user_model.dart';

import 'package:reem/features/profile/data/models/order_model.dart';
import 'package:reem/features/profile/data/models/wishlist_model.dart';

abstract interface class ProfileRemoteDataSource {
  Future<UserModel> getProfile();

  Future<List<ProductModel>> getFavorites();

  Future<WishlistOverviewModel> getWishlistOverview();

  Future<List<OrderModel>> getOrders();


  Future<void> saveSeller(String sellerId);

  Future<void> savePost(String postId);

  Future<WishlistCollectionModel> createWishlistCollection({
    required String name,
    String? description,
  });

  Future<WishlistShareLinkModel> shareWishlistCollection(String collectionId);

  /// Files an already-saved thing into one of her collections.
  ///
  /// [type] is `product`, `post` or `seller`; the server takes it alongside the
  /// matching id and is idempotent, so filing the same piece twice updates the
  /// row rather than creating a second one.
  Future<void> addToWishlistCollection({
    required String collectionId,
    required String type,
    String? productId,
    String? postId,
    String? sellerId,
  });

  Future<void> removeFromWishlistCollection({
    required String collectionId,
    required String itemId,
  });
}
