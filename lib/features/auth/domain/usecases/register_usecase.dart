import 'package:reem/core/result/result.dart';
import 'package:reem/core/shared/entities/user.dart';

import '../repositories/auth_repository.dart';

class RegisterUseCase {
  const RegisterUseCase(this._repository);
  final AuthRepository _repository;

  Future<Result<User>> call({
    required String name,
    String? email,
    required String phone,
    required String password,
    UserRole role = UserRole.customer,
  }) =>
      _repository.register(
        name: name,
        email: email,
        phone: phone,
        password: password,
        role: role,
      );
}
