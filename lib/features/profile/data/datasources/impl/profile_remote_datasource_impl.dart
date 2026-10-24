import 'package:ohara/core/network/api_endpoints.dart';
import 'package:ohara/core/network/base_remote_datasource.dart';
import 'package:ohara/core/shared/models/product_model.dart';
import 'package:ohara/core/shared/models/user_model.dart';
import 'package:ohara/features/profile/data/datasources/profile_remote_datasource.dart';
import 'package:ohara/features/profile/data/models/order_model.dart';
import 'package:ohara/features/profile/data/models/wishlist_model.dart';

final class ProfileRemoteDataSourceImpl extends BaseRemoteDataSource
    implements ProfileRemoteDataSource {
  const ProfileRemoteDataSourceImpl(super.dio);

  @override
  Future<UserModel> getProfile() async {
    final json = await getJson(ApiEndpoints.usersMe);
    final userJson = json['user'] is Map<String, dynamic>
        ? json['user'] as Map<String, dynamic>
        : json;
    return UserModel.fromJson(userJson);
  }

  @override
  Future<List<ProductModel>> getFavorites() async {
    final list = await getList(ApiEndpoints.favorites);
    return list
        .whereType<Map>()
        .map((e) {
          final map = Map<String, dynamic>.from(e);
          final product = map['product'] is Map
              ? Map<String, dynamic>.from(map['product'] as Map)
              : map;
          return ProductModel.fromJson(product);
        })
        .toList();
  }

  @override
  Future<WishlistOverviewModel> getWishlistOverview() async {
    final json = await getJson(ApiEndpoints.favoritesOverview);
    return WishlistOverviewModel.fromJson(json);
  }

  @override
  Future<List<OrderModel>> getOrders() async {
    final list = await getList(ApiEndpoints.orders);
    return list
        .whereType<Map>()
        .map((e) => OrderModel.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  @override
  Future<void> saveSeller(String sellerId) async {
    await postJson(ApiEndpoints.favoriteSeller(sellerId));
  }

  @override
  Future<void> savePost(String postId) async {
    await postJson(ApiEndpoints.favoritePost(postId));
  }

  @override
  Future<WishlistCollectionModel> createWishlistCollection({
    required String name,
    String? description,
  }) async {
    final json = await postJson(
      ApiEndpoints.wishlistCollections,
      body: {
        'name': name,
        if (description != null && description.trim().isNotEmpty)
          'description': description.trim(),
      },
    );
    return WishlistCollectionModel.fromJson(json);
  }

  @override
  Future<void> addToWishlistCollection({
    required String collectionId,
    required String type,
    String? productId,
    String? postId,
    String? sellerId,
  }) async {
    await postJson(
      ApiEndpoints.wishlistCollectionItems(collectionId),
      body: {
        'type': type,
        'product_id': ?productId,
        'post_id': ?postId,
        'seller_id': ?sellerId,
      },
    );
  }

  @override
  Future<void> removeFromWishlistCollection({
    required String collectionId,
    required String itemId,
  }) async {
    await deleteJson(ApiEndpoints.wishlistCollectionItem(collectionId, itemId));
  }

  @override
  Future<WishlistShareLinkModel> shareWishlistCollection(
    String collectionId,
  ) async {
    final json = await postJson(ApiEndpoints.wishlistCollectionShare(collectionId));
    return WishlistShareLinkModel.fromJson(json);
  }
}
