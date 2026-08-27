import 'package:reem/core/result/result.dart';
import 'package:reem/features/auth/domain/entities/auth_account.dart';

import 'package:reem/features/auth/domain/repositories/auth_repository.dart';

class RequestOtpUseCase {
  const RequestOtpUseCase(this._repository);
  final AuthRepository _repository;

  Future<Result<OtpChallenge>> call({
    required String phone,
    required OtpPurpose purpose,
  }) =>
      _repository.requestOtp(phone: phone, purpose: purpose);
}

class VerifyOtpUseCase {
  const VerifyOtpUseCase(this._repository);
  final AuthRepository _repository;

  Future<Result<void>> call({
    required String phone,
    required OtpPurpose purpose,
    required String code,
  }) =>
      _repository.verifyOtp(phone: phone, purpose: purpose, code: code);
}

class ResetPasswordUseCase {
  const ResetPasswordUseCase(this._repository);
  final AuthRepository _repository;

  Future<Result<void>> call({
    required String phone,
    required String code,
    required String newPassword,
  }) =>
      _repository.resetPassword(
        phone: phone,
        code: code,
        newPassword: newPassword,
      );
}
