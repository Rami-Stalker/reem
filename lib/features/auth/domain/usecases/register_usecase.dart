import 'package:reem/core/result/result.dart';
import 'package:reem/core/shared/entities/user.dart';

import 'package:reem/features/auth/domain/repositories/auth_repository.dart';

class RegisterUseCase {
  const RegisterUseCase(this._repository);
  final AuthRepository _repository;

  Future<Result<User>> call({
    required String firstName,
    required String lastName,
    required String phone,
    required String registrationTicket,
    String? password,
    required String country,
    required String city,
    required bool declaredFemale,
    UserRole role = UserRole.customer,
  }) =>
      _repository.register(
        firstName: firstName,
        lastName: lastName,
        phone: phone,
        registrationTicket: registrationTicket,
        password: password,
        country: country,
        city: city,
        declaredFemale: declaredFemale,
        role: role,
      );
}
