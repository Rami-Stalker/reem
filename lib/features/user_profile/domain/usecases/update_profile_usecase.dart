import 'package:ohara/core/result/result.dart';
import 'package:ohara/core/shared/entities/user.dart';

import 'package:ohara/features/user_profile/domain/repositories/user_profile_repository.dart';

class UpdateProfileUseCase {
  const UpdateProfileUseCase(this._repository);
  final UserProfileRepository _repository;

  Future<Result<User>> call({
    String? name,
    String? bio,
    String? imageUrl,
    String? location,
    String? email,
  }) => _repository.updateProfile(
    name: name,
    bio: bio,
    imageUrl: imageUrl,
    location: location,
    email: email,
  );
}
