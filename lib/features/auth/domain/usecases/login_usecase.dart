import 'package:ohara/core/result/result.dart';
import 'package:ohara/core/shared/entities/user.dart';

import 'package:ohara/features/auth/domain/repositories/auth_repository.dart';

class LoginUseCase {
  const LoginUseCase(this._repository);
  final AuthRepository _repository;

  Future<Result<User>> call({
    required String phone,
    required String password,
    required bool rememberMe,
  }) => _repository.login(
    phone: phone,
    password: password,
    rememberMe: rememberMe,
  );
}
