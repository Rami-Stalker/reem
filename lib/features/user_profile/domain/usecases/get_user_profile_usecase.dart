import 'package:reem/core/result/result.dart';

import '../entities/user_profile.dart';
import '../repositories/user_profile_repository.dart';

class GetUserProfileUseCase {
  const GetUserProfileUseCase(this._repository);
  final UserProfileRepository _repository;

  Future<Result<UserProfile>> call(String userId) =>
      _repository.getProfile(userId);
}
