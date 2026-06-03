import 'package:reem/core/result/result.dart';

import '../repositories/auth_repository.dart';

class ForgotPasswordUseCase {
  const ForgotPasswordUseCase(this._repository);
  final AuthRepository _repository;

  Future<Result<void>> call({required String email}) =>
      _repository.forgotPassword(email: email);
}
