import 'package:reem/core/result/result.dart';
import 'package:reem/core/shared/entities/user.dart';

import 'package:reem/features/user_profile/domain/repositories/user_profile_repository.dart';

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
