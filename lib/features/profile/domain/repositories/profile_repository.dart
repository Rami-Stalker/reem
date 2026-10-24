import 'package:ohara/core/result/result.dart';
import 'package:ohara/core/shared/entities/product.dart';
import 'package:ohara/core/shared/entities/user.dart';

import 'package:ohara/features/profile/domain/entities/order_entity.dart';
import 'package:ohara/features/profile/domain/entities/wishlist_entity.dart';

abstract interface class ProfileRepository {
  Future<Result<User>> getProfile();

  Future<Result<List<Product>>> getFavorites();

  Future<Result<WishlistOverview>> getWishlistOverview();

  Future<Result<List<OrderEntity>>> getOrders();


  Future<Result<void>> saveSeller(String sellerId);

  Future<Result<void>> savePost(String postId);

  Future<Result<WishlistCollection>> createWishlistCollection({
    required String name,
    String? description,
  });

  Future<Result<WishlistShareLink>> shareWishlistCollection(String collectionId);

  Future<Result<void>> addToWishlistCollection({
    required String collectionId,
    required String type,
    String? productId,
    String? postId,
    String? sellerId,
  });

  Future<Result<void>> removeFromWishlistCollection({
    required String collectionId,
    required String itemId,
  });
}
