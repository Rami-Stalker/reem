import 'package:reem/core/base/repository_handler.dart';
import 'package:reem/core/result/result.dart';
import 'package:reem/core/shared/entities/product.dart';
import 'package:reem/core/shared/entities/user.dart';
import 'package:reem/features/profile/data/datasources/profile_remote_datasource.dart';
import 'package:reem/features/profile/domain/entities/order_entity.dart';
import 'package:reem/features/profile/domain/entities/wishlist_entity.dart';
import 'package:reem/features/profile/domain/repositories/profile_repository.dart';

class ProfileRepositoryImpl with RepositoryHandler implements ProfileRepository {
  const ProfileRepositoryImpl({required this.remote});

  final ProfileRemoteDataSource remote;

  @override
  Future<Result<User>> getProfile() => guard(() => remote.getProfile());

  @override
  Future<Result<List<Product>>> getFavorites() =>
      guard(() => remote.getFavorites());

  @override
  Future<Result<WishlistOverview>> getWishlistOverview() =>
      guard(() => remote.getWishlistOverview());

  @override
  Future<Result<List<OrderEntity>>> getOrders() =>
      guard(() => remote.getOrders());

  @override
  Future<Result<void>> saveSeller(String sellerId) =>
      guard(() => remote.saveSeller(sellerId));

  @override
  Future<Result<void>> savePost(String postId) => guard(() => remote.savePost(postId));

  @override
  Future<Result<WishlistCollection>> createWishlistCollection({
    required String name,
    String? description,
  }) =>
      guard(
        () => remote.createWishlistCollection(
          name: name,
          description: description,
        ),
      );

  @override
  Future<Result<WishlistShareLink>> shareWishlistCollection(String collectionId) =>
      guard(() => remote.shareWishlistCollection(collectionId));

  @override
  Future<Result<void>> addToWishlistCollection({
    required String collectionId,
    required String type,
    String? productId,
    String? postId,
    String? sellerId,
  }) => guard(
    () => remote.addToWishlistCollection(
      collectionId: collectionId,
      type: type,
      productId: productId,
      postId: postId,
      sellerId: sellerId,
    ),
  );

  @override
  Future<Result<void>> removeFromWishlistCollection({
    required String collectionId,
    required String itemId,
  }) => guard(
    () => remote.removeFromWishlistCollection(
      collectionId: collectionId,
      itemId: itemId,
    ),
  );
}
