import 'package:reem/core/result/result.dart';
import 'package:reem/core/shared/entities/product.dart';

import 'package:reem/features/profile/domain/repositories/profile_repository.dart';

class GetFavoritesUseCase {
  const GetFavoritesUseCase(this._repository);
  final ProfileRepository _repository;

  Future<Result<List<Product>>> call() => _repository.getFavorites();
}
