import 'package:ohara/core/result/result.dart';
import 'package:ohara/core/shared/entities/user.dart';

import 'package:ohara/features/auth/domain/repositories/auth_repository.dart';

class GetCurrentUserUseCase {
  const GetCurrentUserUseCase(this._repository);
  final AuthRepository _repository;

  Future<Result<User?>> call() => _repository.getCurrentUser();
}
