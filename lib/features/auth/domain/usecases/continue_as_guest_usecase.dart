import 'package:reem/core/result/result.dart';

import '../repositories/auth_repository.dart';

class ContinueAsGuestUseCase {
  const ContinueAsGuestUseCase(this._repository);
  final AuthRepository _repository;

  Future<Result<void>> call() => _repository.continueAsGuest();
}
