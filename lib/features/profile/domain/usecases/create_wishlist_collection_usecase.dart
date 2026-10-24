import 'package:ohara/core/result/result.dart';

import 'package:ohara/features/profile/domain/entities/wishlist_entity.dart';
import 'package:ohara/features/profile/domain/repositories/profile_repository.dart';

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
