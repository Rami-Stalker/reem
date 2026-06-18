import 'package:reem/core/result/result.dart';

import '../entities/wishlist_entity.dart';
import '../repositories/profile_repository.dart';

class ShareWishlistCollectionUseCase {
  const ShareWishlistCollectionUseCase(this.repository);

  final ProfileRepository repository;

  Future<Result<WishlistShareLink>> call(String collectionId) {
    return repository.shareWishlistCollection(collectionId);
  }
}
