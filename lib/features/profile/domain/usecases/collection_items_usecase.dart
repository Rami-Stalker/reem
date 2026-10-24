import 'package:ohara/core/result/result.dart';

import 'package:ohara/features/profile/domain/repositories/profile_repository.dart';

/// Files a saved product, post or seller into one of her collections.
class AddToWishlistCollectionUseCase {
  const AddToWishlistCollectionUseCase(this.repository);

  final ProfileRepository repository;

  Future<Result<void>> call({
    required String collectionId,
    required String type,
    String? productId,
    String? postId,
    String? sellerId,
  }) => repository.addToWishlistCollection(
    collectionId: collectionId,
    type: type,
    productId: productId,
    postId: postId,
    sellerId: sellerId,
  );
}

/// Takes it back out of one. The thing stays saved either way — a collection
/// is where a saved piece is filed, not whether it is saved.
class RemoveFromWishlistCollectionUseCase {
  const RemoveFromWishlistCollectionUseCase(this.repository);

  final ProfileRepository repository;

  Future<Result<void>> call({
    required String collectionId,
    required String itemId,
  }) => repository.removeFromWishlistCollection(
    collectionId: collectionId,
    itemId: itemId,
  );
}
