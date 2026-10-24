import 'package:ohara/core/result/result.dart';
import 'package:ohara/core/shared/entities/user.dart';

import 'package:ohara/features/profile/domain/repositories/profile_repository.dart';

class GetProfileUseCase {
  const GetProfileUseCase(this._repository);
  final ProfileRepository _repository;

  Future<Result<User>> call() => _repository.getProfile();
}
