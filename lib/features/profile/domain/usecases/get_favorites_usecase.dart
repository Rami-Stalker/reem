import 'package:ohara/core/result/result.dart';
import 'package:ohara/core/shared/entities/product.dart';

import 'package:ohara/features/profile/domain/repositories/profile_repository.dart';

class GetFavoritesUseCase {
  const GetFavoritesUseCase(this._repository);
  final ProfileRepository _repository;

  Future<Result<List<Product>>> call() => _repository.getFavorites();
}
