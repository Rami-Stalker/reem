import 'package:reem/core/result/result.dart';
import 'package:reem/core/shared/entities/user.dart';

import 'package:reem/features/profile/domain/repositories/profile_repository.dart';

class GetProfileUseCase {
  const GetProfileUseCase(this._repository);
  final ProfileRepository _repository;

  Future<Result<User>> call() => _repository.getProfile();
}
