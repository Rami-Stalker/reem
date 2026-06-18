import 'package:reem/core/result/result.dart';

import '../entities/wishlist_entity.dart';
import '../repositories/profile_repository.dart';

class GetWishlistOverviewUseCase {
  const GetWishlistOverviewUseCase(this.repository);

  final ProfileRepository repository;

  Future<Result<WishlistOverview>> call() => repository.getWishlistOverview();
}
