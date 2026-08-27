import 'package:reem/core/result/result.dart';
import 'package:reem/core/shared/entities/user.dart';

import 'package:reem/features/settings/domain/repositories/settings_repository.dart';

class UpdateProfileUseCase {
  const UpdateProfileUseCase(this._repository);
  final SettingsRepository _repository;

  Future<Result<User>> call({
    String? name,
    String? bio,
    String? imageUrl,
  }) =>
      _repository.updateProfile(name: name, bio: bio, imageUrl: imageUrl);
}
