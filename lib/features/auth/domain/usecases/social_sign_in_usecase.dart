import 'package:reem/core/result/result.dart';
import 'package:reem/core/shared/entities/user.dart';
import 'package:reem/features/auth/domain/entities/auth_account.dart';

import '../repositories/auth_repository.dart';

class SocialSignInUseCase {
  const SocialSignInUseCase(this._repository);
  final AuthRepository _repository;

  Future<Result<User>> call(SocialAuthProvider provider) =>
      _repository.socialSignIn(provider);
}
