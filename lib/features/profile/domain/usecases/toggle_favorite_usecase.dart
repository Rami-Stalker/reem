import 'package:reem/core/result/result.dart';

import 'package:reem/features/profile/domain/repositories/profile_repository.dart';

class ToggleFavoriteUseCase {
  const ToggleFavoriteUseCase(this._repository);
  final ProfileRepository _repository;

  Future<Result<void>> call(String productId) =>
      _repository.toggleFavorite(productId);
}
