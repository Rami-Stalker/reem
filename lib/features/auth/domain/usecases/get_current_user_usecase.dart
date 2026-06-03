import 'package:reem/core/result/result.dart';
import 'package:reem/core/shared/entities/user.dart';

import '../repositories/auth_repository.dart';

class GetCurrentUserUseCase {
  const GetCurrentUserUseCase(this._repository);
  final AuthRepository _repository;

  Future<Result<User?>> call() => _repository.getCurrentUser();
}
