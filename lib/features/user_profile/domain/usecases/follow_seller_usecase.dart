import 'package:reem/core/result/result.dart';

import 'package:reem/features/user_profile/domain/entities/follow_result.dart';
import 'package:reem/features/user_profile/domain/repositories/user_profile_repository.dart';

class FollowSellerUseCase {
  const FollowSellerUseCase(this._repository);
  final UserProfileRepository _repository;

  Future<Result<FollowResult>> call(String userId) =>
      _repository.follow(userId);
}
