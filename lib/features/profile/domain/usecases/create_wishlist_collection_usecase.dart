import 'package:reem/core/result/result.dart';

import '../entities/wishlist_entity.dart';
import '../repositories/profile_repository.dart';

class CreateWishlistCollectionUseCase {
  const CreateWishlistCollectionUseCase(this.repository);

  final ProfileRepository repository;

  Future<Result<WishlistCollection>> call({
    required String name,
    String? description,
  }) {
    return repository.createWishlistCollection(
      name: name,
      description: description,
    );
  }
}
