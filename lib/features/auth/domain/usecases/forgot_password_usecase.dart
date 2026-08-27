import 'package:reem/core/result/result.dart';

import 'package:reem/features/auth/domain/repositories/auth_repository.dart';

class ForgotPasswordUseCase {
  const ForgotPasswordUseCase(this._repository);
  final AuthRepository _repository;

  Future<Result<void>> call({required String phone}) =>
      _repository.forgotPassword(phone: phone);
}
