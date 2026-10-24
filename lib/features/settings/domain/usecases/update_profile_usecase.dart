import 'package:ohara/core/result/result.dart';
import 'package:ohara/core/shared/entities/user.dart';

import 'package:ohara/features/settings/domain/repositories/settings_repository.dart';

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
