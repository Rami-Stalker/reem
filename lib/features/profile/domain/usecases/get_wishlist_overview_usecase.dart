import 'package:ohara/core/result/result.dart';

import 'package:ohara/features/profile/domain/entities/wishlist_entity.dart';
import 'package:ohara/features/profile/domain/repositories/profile_repository.dart';

class GetWishlistOverviewUseCase {
  const GetWishlistOverviewUseCase(this.repository);

  final ProfileRepository repository;

  Future<Result<WishlistOverview>> call() => repository.getWishlistOverview();
}
