import 'package:reem/core/result/result.dart';

import '../entities/user_profile.dart';
import '../repositories/user_profile_repository.dart';

class GetMyProfileUseCase {
  const GetMyProfileUseCase(this._repository);
  final UserProfileRepository _repository;

  Future<Result<UserProfile>> call() => _repository.getMyProfile();
}
