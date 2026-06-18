import 'package:reem/core/result/result.dart';
import 'package:reem/core/shared/entities/user.dart';

import '../repositories/auth_repository.dart';

class LoginUseCase {
  const LoginUseCase(this._repository);
  final AuthRepository _repository;

  Future<Result<User>> call({
    required String phone,
    required String password,
  }) =>
      _repository.login(phone: phone, password: password);
}
