import 'package:reem/core/result/result.dart';

import 'package:reem/features/user_profile/domain/entities/user_profile.dart';
import 'package:reem/features/user_profile/domain/repositories/user_profile_repository.dart';

class GetMyProfileUseCase {
  const GetMyProfileUseCase(this._repository);
  final UserProfileRepository _repository;

  Future<Result<UserProfile>> call() => _repository.getMyProfile();
}
